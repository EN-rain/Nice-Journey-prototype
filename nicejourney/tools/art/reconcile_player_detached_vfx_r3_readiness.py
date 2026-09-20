"""Record exact, still-unapproved player R3 separation in both inventories.

Read-only by default; --apply changes exactly interact/use_item asset records.
Their live resources, original sources, classification counts and final acceptance
remain untouched. Requires independent source and real-renderer gates to pass.
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
REVIEW = ROOT / "assets/art/player/animations/review_r3"
MANIFEST = REVIEW / "player_detached_vfx_v03_r3_candidate_manifest.json"
NATIVE = REVIEW / "engine/player_r3_native_evidence.json"
INVENTORIES = (ROOT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
               ROOT / "docs/art/ASSET_PRODUCTION_MANIFEST.json")
ASSET_ID = "asset:player/animations/player_body_%s_sheet"


def sha(file: Path) -> str:
    return hashlib.sha256(file.read_bytes()).hexdigest()


def evidence() -> dict:
    # These independent read-only audits fail before either manifest is touched.
    runpy.run_path(str(ROOT / "tools/art/check_player_detached_vfx_v03_r3.py"))
    runpy.run_path(str(ROOT / "tools/art/check_player_detached_vfx_v03_r3_native.py"))
    source = json.loads(MANIFEST.read_text(encoding="utf-8"))
    native = json.loads(NATIVE.read_text(encoding="utf-8"))
    assert len(source["records"]) == 2 and len(native["pages"]) == 8
    return {rec["state"]: {
        "status": "NON_PRODUCTION_CANDIDATE_ART_AND_EVENT_TIMING_UNAPPROVED",
        "immutable_original_generated_source_sha256": rec["source_original_sha256"],
        "source_r2": rec["source_r2"],
        "source_r2_sha256": rec["source_r2_sha256"],
        "body_r3_review": rec["body_candidate"],
        "body_r3_sha256": rec["body_candidate_sha256"],
        "vfx_r3_review": rec["vfx_candidate"],
        "vfx_r3_sha256": rec["vfx_candidate_sha256"],
        "candidate_manifest": "res://assets/art/player/animations/review_r3/" + MANIFEST.name,
        "candidate_manifest_sha256": sha(MANIFEST),
        "native_review_manifest": "res://assets/art/player/animations/review_r3/engine/" + NATIVE.name,
        "native_review_manifest_sha256": sha(NATIVE),
        "separable_pixels": 10,
        "separated_at_frame": rec["detached_components"][0]["frame"],
        "frame_count_retained": rec["frame_count"],
        "real_gl_capture_pages": 4,
        "native_verification": "Real player scene GL Compatibility; source and split render identical, right/left, 1x/2x, none/melee; no live resource edits",
        "real_gameplay_vfx_event_and_timing_authorized": False,
        "final_art_approval": False,
    } for rec in source["records"]}


def updated(path: Path, proof: dict) -> tuple[bytes, bytes]:
    before = path.read_bytes()
    text = before.decode("utf-8")
    parsed = json.loads(text)
    assert len(parsed["assets"]) == 223
    assert parsed["classification_counts"]["ACCEPTED_DO_NOT_REGENERATE"] == 178
    assets = {item["stable_asset_id"]: item for item in parsed["assets"]}
    for state in ("interact", "use_item"):
        asset_id = ASSET_ID % state
        item = assets[asset_id].copy()
        if item["classification"] != "EXISTS_NEEDS_REVISION":
            raise ValueError(f"R3 cannot promote/modify unexpected {asset_id} classification")
        item["verified_evidence"] = dict(item["verified_evidence"])
        item["verified_evidence"]["detached_vfx_r3_review_only"] = proof[state]
        item["current_implementation_status"] = (
            "Original live player animation unchanged; source-exact R3 body/VFX candidate "
            "and isolated native renderer review verified, pending art approval and "
            "Inspector-authored live presentation/event timing")
        issue = ("R3 source-exact candidate isolates 10 detached pixels in frame "
                 f"{proof[state]['separated_at_frame']}; candidate is NOT a production "
                 "texture or approved separate event/timing.")
        item["issues"] = list(item["issues"])
        if issue not in item["issues"]:
            item["issues"].append(issue)
        text = replace_object(text, asset_id, item)
    after = json.loads(text)
    assert after["classification_counts"] == parsed["classification_counts"]
    assert len(after["assets"]) == 223
    assert all(x["classification"] == y["classification"]
               for x, y in zip(after["assets"], parsed["assets"]))
    return before, text.encode("utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    proof = evidence()
    results = {path: updated(path, proof) for path in INVENTORIES}
    if args.apply:
        for path, (before, updated_bytes) in results.items():
            if path.read_bytes() != before:
                raise ValueError("manifest changed during reconciliation")
            if updated_bytes != before:
                temporary = path.with_name(path.name + ".player-r3-tmp")
                temporary.write_bytes(updated_bytes)
                os.replace(temporary, path)
    for path, (before, updated_bytes) in results.items():
        print(f"{'UPDATED' if args.apply else 'READY'} {path} changed={updated_bytes != before}")
    print("PASS R3 truthful review evidence; 178 accepted / 45 open; no live sprite binding")


if __name__ == "__main__":
    main()
