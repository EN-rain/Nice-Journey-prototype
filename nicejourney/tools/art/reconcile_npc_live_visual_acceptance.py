"""Accept only four NPC identities whose real Region3/Tower consumers are proven.

Lore and variable-quest identities stay revision records until actual authored
actor anchors exist. Escort movement remains its separate animation record.
Never mutate original source/derivative PNGs or invent actor positions.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from PIL import Image

from audit_npc_static_anchors_v01 import audit as audit_static
from check_npc_live_renderer_v01 import check as audit_live_renderer
from reconcile_current_ui_icon_inventory import corrected_counts, replace_object
from reconcile_region3_decorative_11_12_acceptance import digest


PROJECT = Path(__file__).resolve().parents[2]
INVENTORIES = (PROJECT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
               PROJECT / "docs/art/ASSET_PRODUCTION_MANIFEST.json")
CAPTURE_DIR = PROJECT / "assets/art/npc/review/live_consumer_v01"
ROLE_CAPTURE = {
    "npc.tower_quest_coordinator": ("quest_hall_coordinator.png",),
    "npc.merchant": ("merchant.png",),
    "npc.blacksmith_upgrader": ("blacksmith.png",),
    "npc.temporary_escort_actor": ("region3_escort_at_authored_start.png", "tower_escort_on_real_floor.png"),
}
CONSUMERS = {
    "npc.tower_quest_coordinator": ("Region3 QuestHall/ServiceInteraction/NpcVisualPresenter",),
    "npc.merchant": ("Region3 GeneralMerchant/ServiceInteraction/NpcVisualPresenter",),
    "npc.blacksmith_upgrader": ("Region3 Blacksmith/ServiceInteraction/NpcVisualPresenter",),
    "npc.temporary_escort_actor": ("Region3EscortActor/NpcVisualPresenter", "TowerFloorSessionHost/TowerEscortRuntime/NpcVisualPresenter"),
}


def acceptance_records() -> dict:
    audit_static()
    audit_live_renderer()
    scene = (PROJECT / "src/world/region3/layout/region3_authored_town_layout.tscn").read_text(encoding="utf-8")
    actor = (PROJECT / "src/world/region3/quests/region3_escort_actor.gd").read_text(encoding="utf-8")
    tower = (PROJECT / "src/world/tower/tower_floor_session_host.gd").read_text(encoding="utf-8")
    for role in ("QuestHall", "Blacksmith", "GeneralMerchant"):
        if f'parent="{role}/ServiceInteraction"' not in scene:
            raise ValueError(f"missing authored service NPC placement: {role}")
    if "NpcVisualPresenter" not in actor or "temporary_escort.tres" not in actor:
        raise ValueError("Region3 escort does not consume static NPC art")
    if "runtime.npc_visual_profile = escort_npc_visual_profile" not in tower:
        raise ValueError("Tower escort does not consume static NPC art")
    proof = {}
    for asset_id, names in ROLE_CAPTURE.items():
        captures = []
        for name in names:
            screenshot = CAPTURE_DIR / name
            with Image.open(screenshot) as frame:
                if frame.size != (640, 360):
                    raise ValueError(f"wrong native renderer size: {name}")
            captures.append({
                "path": "res://assets/art/npc/review/live_consumer_v01/" + name,
                "sha256": digest(screenshot),
                "dimensions": [640, 360],
                "source_pixels_matched": "all near-opaque pixels, independently checked by check_npc_live_renderer_v01.py",
            })
        proof[asset_id] = captures
    return proof


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    options = parser.parse_args()
    proof = acceptance_records()
    canonical = {item["stable_asset_id"]: item for item in json.loads(INVENTORIES[0].read_text(encoding="utf-8"))["assets"]}
    for inventory in INVENTORIES:
        before = inventory.read_bytes()
        text = before.decode("utf-8")
        current = {entry["stable_asset_id"]: entry for entry in json.loads(text)["assets"]}
        for asset_id, captures in proof.items():
            entry = current[asset_id].copy()
            if entry["classification"] not in ("EXISTS_NEEDS_REVISION", "ACCEPTED_DO_NOT_REGENERATE"):
                raise ValueError(f"unexpected NPC classification: {asset_id}")
            baseline = canonical[asset_id]
            expected_sha = baseline["verified_evidence"]["production_sha256"]
            production = PROJECT / baseline["current_existing_asset"].removeprefix("res://")
            if digest(production) != expected_sha:
                raise ValueError(f"NPC production art changed: {asset_id}")
            entry["current_existing_asset"] = baseline["current_existing_asset"]
            entry["classification"] = "ACCEPTED_DO_NOT_REGENERATE"
            entry["generation_revision_requirement"] = "NONE: preserve accepted static identity and its verified live consumer; escort movement is a separate animation record"
            entry["current_implementation_status"] = "Exact accepted NPC anchor visibly rendered at existing authored consumer; actual 640x360 Godot source-pixel comparison passed"
            entry["acceptance_scope"] = "Static identity/source/derivative and real actor presentation only; NPC movement and unplaced story/variable roles remain separate"
            entry["verified_evidence"] = {**baseline["verified_evidence"],
                                          "live_consumers": list(CONSUMERS[asset_id]),
                                          "live_renderer_captures": captures,
                                          "pixel_acceptance_checker": "res://tools/art/check_npc_live_renderer_v01.py"}
            entry["issues"] = []
            text = replace_object(text, asset_id, entry)
        text, counts = corrected_counts(text)
        if options.apply:
            if inventory.read_bytes() != before:
                raise ValueError(f"concurrent inventory edit: {inventory}")
            temporary = inventory.with_name(inventory.name + ".npc-sync-tmp")
            temporary.write_bytes(text.encode("utf-8"))
            os.replace(temporary, inventory)
        print(f"{'UPDATED' if options.apply else 'READY'} {inventory}: NPC static live=4/4; accepted={counts['ACCEPTED_DO_NOT_REGENERATE']} revision={counts['EXISTS_NEEDS_REVISION']}")


if __name__ == "__main__":
    main()
