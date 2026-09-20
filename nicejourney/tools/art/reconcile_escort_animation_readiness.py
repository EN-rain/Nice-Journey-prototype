#!/usr/bin/env python3
"""Reconcile truthful escort-animation readiness in both 223-asset authorities.

This tool does NOT produce animation art or accept the P0 animation. Its only
source is the preserved, accepted static escort anchor and proposed NPC bible.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

from reconcile_current_ui_icon_inventory import corrected_counts, replace_object

PROJECT = Path(__file__).resolve().parents[2]
INVENTORIES = (PROJECT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
               PROJECT / "docs/art/ASSET_PRODUCTION_MANIFEST.json")
ASSET_ID = "npc.temporary_escort_actor.animation"
ANCHOR_PATH = "res://assets/art/npc/escort_anchor_v01.png"
ANCHOR_SHA = "2cfa01c99e1716c168a69aff61cda8593c9ebac7e06e4ba39aa23d764aafd84e"
TEST = "res://tests/test_escort_animation_intake_gate.gd"


def prepare() -> dict:
    actual = PROJECT / ANCHOR_PATH.removeprefix("res://")
    review = PROJECT / "assets/art/generated_sources/imagegen/npc/review/npc_escort_anchor_v01.png"
    if (hashlib.sha256(actual.read_bytes()).hexdigest() != ANCHOR_SHA
            or hashlib.sha256(review.read_bytes()).hexdigest() != ANCHOR_SHA):
        raise ValueError("accepted static escort identity no longer matches its verified 32px source")
    profile = (PROJECT / "src/world/npc/presentation/profiles/temporary_escort.tres").read_text(encoding="utf-8")
    if ANCHOR_PATH not in profile or "animation_library =" in profile:
        raise ValueError("escort static identity changed or an animation was bound without intake")
    bible = (PROJECT / "docs/art/NPC_VISUAL_DESIGN_BIBLE.md").read_text(encoding="utf-8")
    if "idle: 4 frames" not in bible or "walk: 6 frames" not in bible:
        raise ValueError("proposed animation counts no longer source-backed")
    validator = (PROJECT / "src/world/npc/presentation/npc_visual_profile.gd").read_text(encoding="utf-8")
    test = (PROJECT / TEST.removeprefix("res://")).read_text(encoding="utf-8")
    if "_validate_escort_animation" not in validator or "genuine source still required" not in test:
        raise ValueError("cannot report an unverified animation intake gate")
    return {
        "accepted_static_source": ANCHOR_PATH,
        "accepted_static_source_sha256": ANCHOR_SHA,
        "accepted_static_source_preserved": True,
        "generation_source_for_motion_received": False,
        "proposed_derivative_layout": "320x32 RGBA: exact 32px cells idle[0..3], walk[4..9]; left mirrored from right-authored source",
        "proposed_frame_counts_from": "res://docs/art/NPC_VISUAL_DESIGN_BIBLE.md:43-54",
        "animation_intake_gate": "res://src/world/npc/presentation/npc_visual_profile.gd",
        "synthetic_contract_test_not_art_acceptance": TEST,
        "live_tower_escort_semantic_handoff": "res://src/world/tower/escorts/tower_escort_runtime.gd",
        "real_gameplay_animation_accepted": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="write only this P0 record in both manifests")
    options = parser.parse_args()
    proof = prepare()
    for path in INVENTORIES:
        before = path.read_bytes()
        source = before.decode("utf-8")
        entries = [entry for entry in json.loads(source)["assets"] if entry["stable_asset_id"] == ASSET_ID]
        if len(entries) != 1:
            raise ValueError("P0 animation record missing/duplicated")
        item = entries[0].copy()
        if item["classification"] != "ANIMATION_REQUIRED" or item["current_existing_asset"] is not None:
            raise ValueError("animation source was falsely accepted or its record changed")
        item["required_views_directions"] = ["right-authored side view; mirrored-left per proposed NPC bible"]
        item["required_animation_states"] = ["idle", "walk"]
        item["required_frame_counts"] = {"idle": 4, "walk": 6, "authority": "proposed NPC visual bible"}
        item["expected_gameplay_dimensions"] = {"derivative_sheet": [320, 32], "cell": [32, 32],
                                                "layout": "proposed four idle cells followed by six walk cells"}
        item["transparency_requirement"] = "32x32 gameplay cells on actual transparent RGBA sheet"
        bible_path = "res://docs/art/NPC_VISUAL_DESIGN_BIBLE.md"
        if bible_path not in item["visual_style_authority"]:
            item["visual_style_authority"].append(bible_path)
        item["reference_assets"] = [ANCHOR_PATH]
        item["target_godot_resource_scene"] = [
            "res://src/world/npc/presentation/profiles/temporary_escort.tres",
            "res://src/world/tower/escorts/tower_escort_runtime.gd",
            "res://src/world/region3/quests/region3_escort_actor.gd",
        ]
        item["current_implementation_status"] = "Accepted static escort sprite is live and the Tower physics wait/follow presentation handoff exists; optional ten-cell animation input now fails closed on bad sheet, tracks and duplicate/noisy poses; genuine generated motion source NOT received"
        item["generation_revision_requirement"] = "Generate genuine right-facing identity-consistent four idle and six walk poses from the accepted static source; visually review full source; deterministically derive ten 32px cells, document hashes/provenance, bind external AnimationLibrary and verify real Godot live gameplay before acceptance"
        item["dependencies"] = [
            "npc.temporary_escort_actor: accepted static anchor preserved and hash-verified",
            "Genuine four idle and six walk source poses plus source/derivative provenance",
            "NPC_VISUAL_DESIGN_BIBLE.md proposed 32px visual conventions and existing Tower wait/follow state mapping",
            "Native live animation visual review; synthetic intake tests are NOT final image acceptance",
        ]
        item["issues"] = ["Motion source, identity-consistent pose review and live animated renderer evidence are still missing; do not generate duplicates from the accepted static anchor"]
        item["partial_integration_evidence"] = proof
        item["verified_evidence"] = {}
        source = replace_object(source, ASSET_ID, item)
        source, counts = corrected_counts(source)
        if counts["ANIMATION_REQUIRED"] != 1 or counts["ACCEPTED_DO_NOT_REGENERATE"] != 177:
            raise ValueError("P0 intake readiness must not alter acceptance totals")
        if options.apply:
            if path.read_bytes() != before:
                raise ValueError("concurrent manifest change")
            temporary = path.with_name(path.name + ".escort-intake-tmp")
            temporary.write_bytes(source.encode("utf-8"))
            os.replace(temporary, path)
        print(f"{'UPDATED' if options.apply else 'READY'} {path}: P0 animation still ANIMATION_REQUIRED, real motion source missing")


if __name__ == "__main__":
    main()
