"""Fail closed when the two 223-asset handoff inventories disagree.

The large Markdown guide/appendix records a frozen historical snapshot; the
root JSON and Godot production JSON are the mutable classification authorities.
Run after any accepted asset slice or before a new worker handoff.
"""

from __future__ import annotations

from collections import Counter
import json
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[2]
INVENTORIES = (
    PROJECT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
    PROJECT / "docs/art/ASSET_PRODUCTION_MANIFEST.json",
)


def check() -> None:
    documents = [json.loads(path.read_text(encoding="utf-8")) for path in INVENTORIES]
    records = []
    for path, document in zip(INVENTORIES, documents):
        entries = document.get("assets")
        if not isinstance(entries, list) or len(entries) != 223:
            raise AssertionError(f"Expected 223 assets in {path}")
        by_id = {entry["stable_asset_id"]: entry for entry in entries}
        if len(by_id) != 223:
            raise AssertionError(f"Repeated stable asset IDs in {path}")
        counts = dict(Counter(entry["classification"] for entry in entries))
        if document.get("classification_counts") != counts:
            raise AssertionError(f"Classification totals disagree with records in {path}: {counts}")
        records.append((by_id, counts))

    left, left_counts = records[0]
    right, right_counts = records[1]
    if left.keys() != right.keys():
        raise AssertionError("Root/project inventories have different asset IDs")
    mismatch = [asset_id for asset_id in left if left[asset_id]["classification"] != right[asset_id]["classification"]]
    if mismatch or left_counts != right_counts:
        raise AssertionError(f"Root/project classification drift: {mismatch}")

    expected_open = {
        "r3:interior:functional:01": "MISSING_GENERATE",
        "r3:interior:functional:08": "MISSING_GENERATE",
        "npc.temporary_escort_actor.animation": "ANIMATION_REQUIRED",
        "asset:environments/tower/tiles/tower_common_tileset": "TEXTURE_TILE_REQUIRED",
        "boss.tenth_warden.telegraph.twin_cut": "VFX_REQUIRED",
        "asset:ui/markers/map_marker_sheet": "ACCEPTED_DO_NOT_REGENERATE",
        "application.icon": "ACCEPTED_DO_NOT_REGENERATE",
    }
    for asset_id, classification in expected_open.items():
        if left[asset_id]["classification"] != classification:
            raise AssertionError(f"Unsafe premature closure of {asset_id}")

    marker = left["asset:ui/markers/map_marker_sheet"]
    evidence = marker.get("verified_evidence", {})
    if (marker.get("current_existing_asset") != "res://assets/art/ui/markers/map_marker_quest_sigil_v02.png"
            or evidence.get("sha256") != "e918f083ae5e1110faed8538112a2b6bb5f973bc367d19234aa26ac7ad5eeb94"
            or evidence.get("map_quest_coordinates_authored") is not False
            or evidence.get("map_travel_action_added") is not False):
        raise AssertionError("Accepted map-sheet art must not invent geographic markers or travel")

    app_icon = left["application.icon"]
    app_proof = app_icon.get("verified_evidence", {})
    if (app_icon.get("current_existing_asset") != "res://assets/art/ui/application/application_icon_tower_sigil_v02.png"
            or app_proof.get("output_sha256") != "26d6b6318856e04bae3b2c32adbce24e5f0c79fa411b9fa7706d2b03fee9f185"
            or app_proof.get("source_sha256") != "1dfeea179a0df7320388fcfadba55e715d367656be4e6585a756b14b99a70b39"
            or app_proof.get("final_product_brand_or_packaged_platform_icon_claimed") is not False):
        raise AssertionError("Accepted prototype icon must stay exact source-backed and not imply final branding/export")

    print(f"ASSET INVENTORY ALIGNMENT PASS: 223 unique IDs, identical classification per ID and totals: {left_counts}")


if __name__ == "__main__":
    check()
