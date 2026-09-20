"""Record genuine but UNAPPROVED omitted V04 poses in both 223-ID inventories.

Default mode is read-only. --apply changes only block and hit candidate evidence;
classification, live resources, accepted sources and production art remain as-is.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import runpy
from pathlib import Path

from reconcile_current_ui_icon_inventory import replace_object


ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "assets/art/player/animations/review_v04_full_source"
MANIFEST = REVIEW / "player_v04_full_source_pose_review_manifest.json"
NATIVE = REVIEW / "engine/player_v04_full_source_native_evidence.json"
INVENTORIES = (ROOT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
               ROOT / "docs/art/ASSET_PRODUCTION_MANIFEST.json")


def sha(source: Path) -> str:
    return hashlib.sha256(source.read_bytes()).hexdigest()


def verified() -> dict:
    # Fail before any manifest is touched if source/GL evidence is stale.
    runpy.run_path(str(ROOT / "tools/art/check_player_v04_omitted_source_review.py"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    native = json.loads(NATIVE.read_text(encoding="utf-8"))
    assert len(manifest["records"]) == 2 and len(native["pages"]) == 8
    return {
        rec["state"]: {
            "status": "REVIEW_ONLY_REAL_GENERATED_SOURCE_POSES_UNAPPROVED_NOT_RUNTIME_BOUND",
            "original_source": rec["original_generated_source"],
            "original_source_sha256": rec["original_generated_source_sha256"],
            "r2_candidate": rec["r2_candidate"],
            "r2_candidate_sha256": rec["r2_candidate_sha256"],
            "full_generated_pose_review": rec["full_source_review"],
            "full_generated_pose_review_sha256": rec["full_source_review_sha256"],
            "full_generated_pose_count": rec["original_source_pose_count"],
            "r2_selected_source_indices_verified_exact": rec["r2_selected_source_indices_verified_exact"],
            "previously_unselected_indices_not_art_approved": rec["newly_exposed_source_indices_unapproved"],
            "frame_rgba_sha256": rec["frame_rgba_sha256"],
            "candidate_manifest": "res://assets/art/player/animations/review_v04_full_source/" + MANIFEST.name,
            "candidate_manifest_sha256": sha(MANIFEST),
            "native_review_manifest": "res://assets/art/player/animations/review_v04_full_source/engine/" + NATIVE.name,
            "native_review_manifest_sha256": sha(NATIVE),
            "real_gl_capture_pages": 4,
            "final_art_approval": False,
            "gameplay_timing_authorized": False,
        }
        for rec in manifest["records"]
    }


def transform(path: Path, proof: dict) -> tuple[bytes, bytes]:
    before = path.read_bytes()
    text = before.decode("utf-8")
    parsed = json.loads(text)
    assert len(parsed["assets"]) == 223
    assert parsed["classification_counts"]["ACCEPTED_DO_NOT_REGENERATE"] == 178
    assets = {item["stable_asset_id"]: item for item in parsed["assets"]}
    for state in ("block", "hit"):
        key = f"asset:player/animations/player_body_{state}_sheet"
        item = assets[key].copy()
        if item["classification"] != "EXISTS_NEEDS_REVISION":
            raise ValueError(f"cannot mark unapproved V04 poses accepted for {key}")
        item["verified_evidence"] = dict(item["verified_evidence"])
        item["verified_evidence"]["full_generated_pose_review_only"] = proof[state]
        item["current_implementation_status"] = (
            "Live Player animation unchanged; real generated V04 source poses omitted from "
            "R2 exposed in isolated native GL review, NOT visually approved or production bound")
        issue = (f"Unapproved V04 source review exposes {proof[state]['full_generated_pose_count']} "
                 f"source frames including {proof[state]['previously_unselected_indices_not_art_approved']}; "
                 "no repeated filler frames or gameplay timing change; source quality still needs review.")
        item["issues"] = list(item["issues"])
        if issue not in item["issues"]:
            item["issues"].append(issue)
        text = replace_object(text, key, item)
    after = json.loads(text)
    assert len(after["assets"]) == 223
    assert after["classification_counts"] == parsed["classification_counts"]
    assert all(x["classification"] == y["classification"]
               for x, y in zip(after["assets"], parsed["assets"]))
    return before, text.encode("utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="update only block/hit evidence")
    args = parser.parse_args()
    proof = verified()
    results = {path: transform(path, proof) for path in INVENTORIES}
    if args.apply:
        for path, (before, new) in results.items():
            if path.read_bytes() != before:
                raise ValueError("manifest changed during review reconciliation")
            if new != before:
                temp = path.with_name(path.name + ".v04-pose-tmp")
                temp.write_bytes(new)
                os.replace(temp, path)
    for path, (before, new) in results.items():
        print(f"{'UPDATED' if args.apply else 'READY'} {path} changed={new != before}")
    print("PASS V04 full generated source review only, 178 accepted / 45 open; no live player edits")


if __name__ == "__main__":
    main()
