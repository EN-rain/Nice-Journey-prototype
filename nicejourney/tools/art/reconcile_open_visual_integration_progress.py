"""Record verified partial progress without falsely accepting unfinished art.

This metadata-only reconciliation is intentionally conservative: live sprite
bindings, preview VFX, candidate art, and reusable TileSets are NOT equivalent
to a new generated source or final renderer/artwork acceptance.
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
INVENTORIES = (PROJECT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
               PROJECT / "docs/art/ASSET_PRODUCTION_MANIFEST.json")
TOWER_ATLAS = PROJECT / "assets/art/environments/tower/tiles/tower_common_tileset_v01.png"
TOWER_TILESET = PROJECT / "src/world/tower/presentation/tower_common_floor_tileset_v01.tres"
TOWER_COMPOSER = PROJECT / "src/world/tower/generation/tower_floor_runtime_composer.gd"
INTERIOR_PACKET = PROJECT / "tools/art/region3_interiors/interior_art_packet_draft_v01.json"
BOSS_PACKET = PROJECT / "tools/art/boss_telegraph_review/boss_art_generation_packet_v01.json"
BOSS_PREVIEW = PROJECT / "tools/art/boss_telegraph_review/tenth_warden_telegraph_review_only.tres"


def verified_progress() -> dict:
    progress: dict[str, dict] = {}
    for name, scene_name, class_id in (
        ("arrow_projectile", "player_arrow_projectile_v02.tscn", "Ranged"),
        ("arcane_projectile", "player_arcane_projectile_v02.tscn", "Mage"),
    ):
        art = PROJECT / f"assets/art/player/weapons/{name}_v02.png"
        scene = PROJECT / f"src/combat/skills/{scene_name}"
        if f"res://assets/art/player/weapons/{name}_v02.png" not in scene.read_text(encoding="utf-8"):
            raise ValueError(f"accepted projectile art not actually in live scene: {name}")
        screenshots = []
        for suffix in ("static", "stable_live", "test_hud_panel_hidden"):
            name_root = 'ranged' if name == 'arrow_projectile' else 'mage'
            file_tail = f"{suffix}_renderer_evidence.png" if suffix != "test_hud_panel_hidden" else "test_hud_panel_hidden_evidence.png"
            png = PROJECT / f"artifacts/combat/player_projectile_{name_root}_v02_{file_tail}"
            with Image.open(png) as image:
                if image.size != (1280, 720):
                    raise ValueError(f"wrong native renderer screenshot: {png}")
            screenshots.append({"path": f"res://{png.relative_to(PROJECT).as_posix()}", "sha256": digest(png)})
        progress[f"asset:player/weapons/{name}"] = {
            "status": f"Existing accepted sprite wired into actual {class_id} basic/active projectile Sprite2D scene; source pixels PASS in real live renderer with HUD panel test-hidden, but default HUD CanvasLayer panel occludes the launch/travel area; normal gameplay visibility approval PENDING",
            "proof": {"live_scene": f"res://src/combat/skills/{scene_name}", "source_sha256": digest(art),
                      "renderer_captures": screenshots,
                      "source_pixel_checker": "res://tools/art/verify_player_projectile_renderer_evidence.py",
                      "static_source_pixels_verified": True,
                      "source_pixels_verified_with_hud_hidden": True,
                      "normal_gameplay_source_pixels_visible": False,
                      "hud_occlusion_cause": "res://src/ui/combat_hud.tscn Root/Panel x8..348 y8..244 on CanvasLayer 20 overlays actual projectile canvas x286..307 y180; world z26 cannot overdraw CanvasLayer 20"},
        }

    tileset_text = TOWER_TILESET.read_text(encoding="utf-8")
    composer_text = TOWER_COMPOSER.read_text(encoding="utf-8")
    if "tower_common_tileset_v01.png" not in tileset_text or "_append_route_floor" not in composer_text or "FloorTiles" not in composer_text:
        raise ValueError("tower floor TileSet not connected to rooms AND routes")
    captures = []
    for name in ("tower-floor-atlas-v01-review.png", "tower-floor-1-connected-route-review.png"):
        image = PROJECT / "docs/evidence/renderer" / name
        with Image.open(image) as png:
            if png.width < 640 or png.height < 360:
                raise ValueError("invalid actual renderer tower capture")
        captures.append({"path": f"res://docs/evidence/renderer/{name}", "sha256": digest(image)})
    progress["asset:environments/tower/tiles/tower_common_tileset"] = {
        "status": "Existing procedural V01 placeholder is now live as editor-owned 32px TileSet and room+graph-route floor TileMapLayers; final generated dark stone/metal replacement source remains MISSING",
        "proof": {"placeholder_atlas_sha256": digest(TOWER_ATLAS),
                  "tile_set_resource": "res://src/world/tower/presentation/tower_common_floor_tileset_v01.tres",
                  "live_consumer": "res://src/world/tower/generation/tower_floor_runtime_composer.gd",
                  "renderer_captures": captures,
                  "final_art_source_generated": False},
    }
    for room in ("combat", "safe", "reward", "vendor", "secret", "elite", "objective", "boss"):
        if not (PROJECT / f"src/world/tower/presentation/profiles/{room}_visual_profile.tres").is_file():
            raise ValueError(f"missing tower semantic room profile {room}")
        progress[f"asset:environments/tower/rooms/tower_room_{room}"] = {
            "status": "Current 96px room-category stamp remains provisional; new 32px procedural floor atlas now covers authored modules and links; final visual stamp or replacement art not generated",
            "proof": {"existing_profile": f"res://src/world/tower/presentation/profiles/{room}_visual_profile.tres",
                      "floor_tile_set": "res://src/world/tower/presentation/tower_common_floor_tileset_v01.tres"},
        }

    interior = json.loads(INTERIOR_PACKET.read_text(encoding="utf-8"))
    if len(interior.get("proposed_scenes", [])) != 8:
        raise ValueError("eight interior roles must remain in the art packet")
    for index in range(1, 9):
        progress[f"r3:interior:functional:{index:02d}"] = {
            "status": "Shared modular interior material-generation packet staged; actual room/entry/exit/interactable geometry unauthored; NO scene or interior art source generated",
            "proof": {"art_packet": "res://tools/art/region3_interiors/interior_art_packet_draft_v01.json",
                      "geometry_approved": False,
                      "source_image_generated": False},
        }
    if not BOSS_PACKET.is_file() or not BOSS_PREVIEW.is_file():
        raise ValueError("five-move boss review packet missing")
    for move in ("twin_cut", "warden_lunge", "arc_volley", "crescent_sweep", "punishing_step"):
        progress[f"boss.tenth_warden.telegraph.{move}"] = {
            "status": "Existing accepted primitive preview isolated; production telegraph unbound because source timing/geometry explicitly PLAYTEST and not final-approved",
            "proof": {"preview_fixture": "res://tools/art/boss_telegraph_review/tenth_warden_telegraph_review_only.tres",
                      "art_packet": "res://tools/art/boss_telegraph_review/boss_art_generation_packet_v01.json",
                      "final_geometry_approved": False, "production_telegraph_bound": False},
        }
    return progress


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    options = parser.parse_args()
    progress = verified_progress()
    for inventory in INVENTORIES:
        before = inventory.read_bytes()
        text = before.decode("utf-8")
        by_id = {item["stable_asset_id"]: item for item in json.loads(text)["assets"]}
        for asset_id, evidence in progress.items():
            item = by_id[asset_id].copy()
            if item["classification"] == "ACCEPTED_DO_NOT_REGENERATE":
                # This script is a partial-progress tracker, not an art approval
                # authority. Once a separately verified record is accepted, do
                # not regress its classification/status or restore stale notes.
                continue
            item["current_implementation_status"] = evidence["status"]
            item["partial_integration_evidence"] = evidence["proof"]
            text = replace_object(text, asset_id, item)
        text, counts = corrected_counts(text)
        if options.apply:
            if inventory.read_bytes() != before:
                raise ValueError(f"concurrent inventory edit: {inventory}")
            temp = inventory.with_name(inventory.name + ".visual-progress-tmp")
            temp.write_bytes(text.encode("utf-8"))
            os.replace(temp, inventory)
        print(f"{'UPDATED' if options.apply else 'READY'} {inventory}: annotated {len(progress)} unresolved records, accepted={counts['ACCEPTED_DO_NOT_REGENERATE']}")


if __name__ == "__main__":
    main()
