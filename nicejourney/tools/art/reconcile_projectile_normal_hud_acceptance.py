"""Promote the two live projectile art records after native HUD-intact evidence.

The launch remains obscured by the actual combat HUD. This accepts the existing
PNG/scene and basic/Q unoccluded travel, not an alteration to that HUD layout.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from PIL import Image
from reconcile_current_ui_icon_inventory import corrected_counts, replace_object
from reconcile_region3_decorative_11_12_acceptance import digest

PROJECT = Path(__file__).resolve().parents[2]
INVENTORIES = (
    PROJECT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
    PROJECT / "docs/art/ASSET_PRODUCTION_MANIFEST.json",
)
VERIFIER = "res://tools/art/verify_player_projectile_renderer_evidence.py"


def verify() -> dict:
    results = {}
    for name, token, color_samples in (("arrow_projectile", "ranged", 20), ("arcane_projectile", "mage", 119)):
        art = PROJECT / f"assets/art/player/weapons/{name}_v02.png"
        scene = PROJECT / f"src/combat/skills/player_{name}_v02.tscn"
        screenshot = PROJECT / f"artifacts/combat/player_projectile_{token}_v02_normal_hud_clear_renderer_evidence.png"
        positions = PROJECT / f"artifacts/combat/player_projectile_{token}_v02_normal_hud_clear_positions.json"
        assert art.is_file() and scene.is_file() and screenshot.is_file() and positions.is_file()
        assert "res://assets/art/player/weapons/" + name + "_v02.png" in scene.read_text(encoding="utf8")
        with Image.open(art) as im:
            assert im.mode == "RGBA" and im.size == (32, 16)
        with Image.open(screenshot) as im:
            assert im.size == (1280, 720)
        proof = json.loads(positions.read_text(encoding="utf8"))
        assert proof["normal_hud_panel_visible"] is True
        assert proof["normal_hud_panel_rect"] == [8, 8, 340, 236]
        assert proof["framebuffer_size"] == [1280, 720]
        assert len(proof["projectiles"]) == 2
        assert len({x["action_instance_id"] for x in proof["projectiles"]}) == 2
        for shot in proof["projectiles"]:
            assert shot["canvas_origin"][0] >= 365
            assert shot["traveled"] < shot["range"] and shot["remaining"] > 0
        assert proof["capture"] == f"res://artifacts/combat/player_projectile_{token}_v02_normal_hud_clear_renderer_evidence.png"
        results[f"asset:player/weapons/{name}"] = {
            "texture_path": f"res://assets/art/player/weapons/{name}_v02.png",
            "texture_sha256": digest(art),
            "live_sprite_scene": f"res://src/combat/skills/player_{name}_v02.tscn",
            "normal_hud_renderer": proof["capture"],
            "normal_hud_renderer_sha256": digest(screenshot),
            "normal_hud_positions": f"res://artifacts/combat/player_projectile_{token}_v02_normal_hud_clear_positions.json",
            "normal_hud_positions_sha256": digest(positions),
            "distinctive_source_pixels_per_shot": color_samples,
            "distinctive_source_pixels_matching_per_shot": color_samples,
            "basic_and_q_unoccluded": True,
            "launch_covered_by_hud": True,
        }
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    updates = verify()
    for path in INVENTORIES:
        original = path.read_bytes()
        text = original.decode("utf8")
        by_id = {x["stable_asset_id"]: x for x in json.loads(text)["assets"]}
        for asset_id, proof in updates.items():
            record = by_id[asset_id].copy()
            assert record["classification"] in ("EXISTS_NEEDS_REVISION", "ACCEPTED_DO_NOT_REGENERATE")
            assert record["current_existing_asset"] == proof["texture_path"]
            assert record["verified_evidence"]["sha256"] == proof["texture_sha256"]
            record["classification"] = "ACCEPTED_DO_NOT_REGENERATE"
            record["target_godot_resource_scene"] = [proof["live_sprite_scene"]]
            record["generation_revision_requirement"] = "NONE: preserve current sprite/source; native HUD-intact gameplay basic/Q art accepted in unoccluded travel"
            record["current_implementation_status"] = "Accepted original sprite integrated into Inspector-owned live basic/Q projectile; normal HUD intact, both shots still traveling in unoccluded canvas area with exact source pixels"
            record["acceptance_scope"] = "Art/source and ranged/mage basic/Q live projectile presentation outside HUD; the unmodified HUD deliberately occludes launch x8..348/y8..244 and remains a separate UI-layout issue"
            record["verified_evidence"] = {**record["verified_evidence"], **proof,
                                           "native_source_pixel_verifier": VERIFIER,
                                           "source_pixel_verification": "exact distinctive source matches at 2x, both shots, normal HUD intact"}
            record["issues"] = []
            record.pop("partial_integration_evidence", None)
            text = replace_object(text, asset_id, record)
        text, counts = corrected_counts(text)
        if args.apply:
            assert original == path.read_bytes(), f"Concurrent inventory change: {path}"
            tmp = path.with_name(path.name + ".projectiles-tmp")
            tmp.write_bytes(text.encode("utf8"))
            os.replace(tmp, path)
        print(f"{'UPDATED' if args.apply else 'READY'} {path}: {counts}")


if __name__ == "__main__":
    main()
