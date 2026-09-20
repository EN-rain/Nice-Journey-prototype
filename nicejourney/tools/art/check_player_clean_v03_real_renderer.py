#!/usr/bin/env python3
"""Fail-closed checks for seven LIVE Godot Compatibility player V03 states.

Does not edit live art, library, manifests, or any screenshot. Validates all
frames (not selected stills), nearest-derived source hashes, two facings,
native/2x source-pixel integrity and actual three-class equipment coverage.
"""
from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "assets/art/player/animations/review_clean_v03_engine"
EVIDENCE = REVIEW / "clean_v03_real_renderer_evidence.json"
NEAREST = ROOT / "docs/evidence/art/nearest_candidates/player_main_character_v03_nearest_derivation_manifest.json"
HANDOFF = ROOT.parent / "Nice_Journey_Asset_Handoff_Manifest.json"
STATES = ("idle", "walk", "run", "dash", "climb", "pickup", "sleep")
PROFILES = {
    "melee": ("res://assets/art/player/weapons/starter_sword_v02.png", (9, -1)),
    "ranged": ("res://assets/art/player/weapons/starter_bow_v02.png", (-6, 0)),
    "mage": ("res://assets/art/player/weapons/starter_staff_v02.png", (3, -10)),
}
SHIELD = "res://assets/art/player/weapons/starter_shield_v02.png"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def path_of(res: str) -> Path:
    assert res.startswith("res://"), res
    p = ROOT / res[6:]
    assert p.is_file(), p
    return p


evidence = json.loads(EVIDENCE.read_text(encoding="utf8"))
nearest = json.loads(NEAREST.read_text(encoding="utf8"))
handoff = json.loads(HANDOFF.read_text(encoding="utf8"))
assert evidence["display"] == "Windows" and evidence["rendering_method"] == "gl_compatibility"
assert evidence["page_count"] == len(evidence["pages"]) == 84
assert sha(path_of(evidence["production_library"])) == evidence["production_library_sha256"]
assert {(p["state"], p["class"], p["zoom"], p["equipped"]) for p in evidence["pages"]} == {
    (s, c, z, equipped) for s in STATES for c in PROFILES for z in (1, 2) for equipped in (False, True)
}
assert evidence["source_scene"] == "res://src/player/player.tscn"

source_files = nearest["sources"]
handoff_records = {
    s: next(x for x in handoff["assets"]
            if x["stable_asset_id"] == f"asset:player/animations/player_body_{s}_sheet")
    for s in STATES
}
metrics = defaultdict(lambda: {"frames": 0, "checked": 0, "matched": 0,
                           "exact": 0, "alpha_levels": set(), "off_canvas": 0,
                           "bottom_rows": set(), "profile_delta_min": {},
                           "grip_gap_max_2x": 0.0})
pages = {}
stale_handoff_sha: list[str] = []
for page in evidence["pages"]:
    state, cls, zoom, equipped = page["state"], page["class"], page["zoom"], page["equipped"]
    path = path_of(page["image"])
    assert sha(path) == page["image_sha256"]
    screenshot = np.asarray(Image.open(path).convert("RGBA"))
    assert screenshot.shape == (360, 640, 4)
    assert screenshot[350, 600].tolist() == [61, 61, 61, 255]
    nearest_record = nearest["animations"][state]
    sheet_path = path_of(page["source"])
    assert page["source"] == nearest_record["output"]
    assert sha(sheet_path) == page["source_sha256"] == nearest_record["output_sha256"]
    sheet = np.asarray(Image.open(sheet_path).convert("RGBA"))
    count = nearest_record["frame_count"]
    assert sheet.shape == (32, 32 * count, 4)
    assert len(page["samples"]) == count * 2
    assert nearest_record["output_dimensions"] == [32 * count, 32]
    source_key = nearest_record["source_file"]
    source_path = ROOT / "assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources" / source_key
    assert sha(source_path) == source_files[source_key]["sha256"]
    assert len(nearest_record["source_cells"]) == count
    assert len(nearest_record["source_row"]) == 2
    asserted_manifest = handoff_records[state]
    assert asserted_manifest["classification"] in ("EXISTS_NEEDS_REVISION", "ACCEPTED_DO_NOT_REGENERATE")
    if asserted_manifest["classification"] == "EXISTS_NEEDS_REVISION":
        assert asserted_manifest["generation_revision_requirement"].startswith("Do not regenerate.")
    limits = asserted_manifest["required_frame_counts"]["specified"]
    assert limits[0] <= count <= limits[1]
    assert asserted_manifest["required_frame_counts"]["current"] == count
    assert asserted_manifest["verified_evidence"]["source_sha256"] == sha(source_path)
    if asserted_manifest["verified_evidence"]["sha256"] != sha(sheet_path):
        stale_handoff_sha.append(state)
    assert (sheet[:, :, 3] == 0).any() and (sheet[:, :, 3] == 255).any()
    assert not np.any(np.any(sheet[:, :, :3] > 0, axis=2) & (sheet[:, :, 3] == 0)), "Nonzero transparent RGB"
    metrics[state]["alpha_levels"].update(np.unique(sheet[:, :, 3]).tolist())
    crop_rgb = {}
    for row in range(2):
        facing = "left" if row == 1 else "right"
        for index in range(count):
            sample = page["samples"][row * count + index]
            assert sample["frame"] == index and sample["frame_count"] == count
            assert sample["source_texture"] == page["source"]
            assert sample["source_sha256"] == page["source_sha256"]
            assert sample["row"] == row and sample["facing"] == facing and sample["zoom"] == zoom
            assert sample["class"] == (cls if equipped else "none")
            assert sample["body_sprite_xy"] == [0, -13]
            assert sample["body_visual_scale_xy"] == ([-1, 1] if facing == "left" else [1, 1])
            pos = sample["player_xy"]
            assert sample["grip_global_xy"] == [pos[0] + (7 if facing == "right" else -7) * zoom, pos[1] - 12 * zoom]
            assert sample["pivot_global_xy"] == sample["grip_global_xy"]
            assert abs(sample["pivot_rotation"] - (0.0 if facing == "right" else np.pi)) < 1e-5
            if equipped:
                assert sample["hand_texture"] == PROFILES[cls][0]
                assert sample["hand_local_xy"] == list(PROFILES[cls][1])
                assert sample["shield_visible"] == (cls == "melee")
                assert sample["shield_texture"] == (SHIELD if cls == "melee" else "")
            else:
                assert sample["hand_texture"] == "" and not sample["shield_visible"]
            x = int(pos[0]) - 16 * zoom
            y = int(pos[1]) - 29 * zoom
            assert x >= 0 and x + 32 * zoom <= 640 and y >= 0 and y + 32 * zoom <= 360
            frame = sheet[:, 32 * index:32 * (index + 1)]
            if not equipped:
                px = np.repeat(np.repeat(frame, zoom, axis=0), zoom, axis=1)
                if facing == "left":
                    px = np.flip(px, axis=1)
                rendered = screenshot[y:y + 32 * zoom, x:x + 32 * zoom, :3]
                alpha = px[:, :, 3:4].astype(np.float64) / 255.0
                composed = px[:, :, :3].astype(np.float64) * alpha + 61.0 * (1 - alpha)
                keep = px[:, :, 3] >= 245
                assert int(keep.sum()) > 40 * zoom * zoom
                delta = np.abs(rendered.astype(np.float64) - composed)
                # Semi-transparent V03 edge pixels (alpha 245..254) differ
                # by up to ~8 channels through native GPU compositing.
                # We require fully opaque 255 samples to be byte-exact.
                matched = int(np.count_nonzero(np.all(delta <= 12, axis=2) & keep))
                assert matched == int(keep.sum()), (state, cls, zoom, facing, index, matched, int(keep.sum()))
                opaque = px[:, :, 3] == 255
                exact = int(np.count_nonzero(np.all(rendered == px[:, :, :3], axis=2) & opaque))
                assert exact == int(opaque.sum()), (state, cls, zoom, facing, index)
                metrics[state]["checked"] += int(keep.sum())
                metrics[state]["matched"] += matched
                metrics[state]["exact"] += exact
                metrics[state]["frames"] += 1
                ys, xs = np.where(frame[:, :, 3] >= 160)
                assert len(xs) > 40 and xs.min() >= 0 and xs.max() <= 31
                assert ys.min() >= 0 and ys.max() <= 31
                metrics[state]["bottom_rows"].add(int(ys.max()))
                # body-to-grip separation is only an objective proxy, not a
                # human-visible proof of anatomical hand/weapon contact.
                if zoom == 2:
                    ys2, xs2 = np.where(px[:, :, 3] >= 160)
                    grip = sample["grip_global_xy"]
                    min_dist = float(np.hypot(xs2 + x - grip[0], ys2 + y - grip[1]).min())
                    metrics[state]["grip_gap_max_2x"] = max(metrics[state]["grip_gap_max_2x"], min_dist)
            crop_rgb[row, index] = screenshot[int(pos[1]) - 58 * zoom // 2:int(pos[1]) + 8 * zoom // 2,
                                               int(pos[0]) - 30 * zoom // 2:int(pos[0]) + 30 * zoom // 2, :3]
    pages[state, cls, zoom, equipped] = crop_rgb

for state in STATES:
    for cls in PROFILES:
        for zoom in (1, 2):
            base = pages[state, cls, zoom, False]
            geared = pages[state, cls, zoom, True]
            changed_pixels = []
            count = nearest["animations"][state]["frame_count"]
            for facing_row in (0, 1):
                for frame in range(count):
                    a = base[facing_row, frame]
                    b = geared[facing_row, frame]
                    assert a.shape == b.shape
                    changed = int(np.count_nonzero(np.any(a != b, axis=2)))
                    assert changed > 8, (state, cls, zoom, facing_row, frame, changed)
                    changed_pixels.append(changed)
            metrics[state]["profile_delta_min"][f"{cls}_{zoom}x"] = min(changed_pixels)

for state in STATES:
    m = metrics[state]
    assert len(m["profile_delta_min"]) == 6
    print("PASS", state, "count", nearest["animations"][state]["frame_count"],
          "source-pixels", m["matched"], "/", m["checked"],
          "alpha255 EXACT", m["exact"], "bottom-rows", sorted(m["bottom_rows"]),
          "grip-proxy-max-2x", round(m["grip_gap_max_2x"], 3),
          "overlay-min", m["profile_delta_min"],
          "intermediate-alpha-levels", sum(0 < a < 255 for a in m["alpha_levels"]))
print("CLEAN LIVE V03 REAL RENDER PASS 84/84 pages, all frames both facings all classes native and 2x")
if stale_handoff_sha:
    print("HANDOFF: stale old LANCZOS SHA256 fields need NEAREST hash reconciliation for", sorted(set(stale_handoff_sha)))
else:
    print("HANDOFF: all seven source/derivative SHA256 values reflect currently live NEAREST resources")
