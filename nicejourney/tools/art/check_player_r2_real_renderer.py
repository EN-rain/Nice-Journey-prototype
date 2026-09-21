"""Read-only source-pixel checks of 50 actual GL Compatibility captures.

The capture metadata is untrusted until the visible native-size sprite pixels
match the exact recorded source frame, both facing directions, both zooms.
Equipment pages use the actual player scene/profile transforms and must have
visible pixels beyond the corresponding no-equipment render. Pixel fidelity
does not establish subjective equipment/grip fit or absence of baked VFX.
"""

import argparse
import hashlib
import json
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image


PROJECT = Path(__file__).resolve().parents[2]
REVIEW = PROJECT / "assets/art/player/animations/review_r2_engine"
MANIFEST = REVIEW / "player_r2_renderer_evidence.json"
REPORT = REVIEW / "player_r2_renderer_verification.json"
PARSER = argparse.ArgumentParser(description=__doc__)
PARSER.add_argument(
    "--write-report", action="store_true",
    help="explicitly refresh this tool's own renderer verification JSON after successful checks",
)
ARGS = PARSER.parse_args()
STATES = (
    "attack", "heavy_attack", "block", "parry", "cast", "hit",
    "interact", "use_item", "death", "dodge",
)
CLASS_TEXTURE = {
    "melee": "res://assets/art/player/weapons/starter_sword_v02.png",
    "ranged": "res://assets/art/player/weapons/starter_bow_v02.png",
    "mage": "res://assets/art/player/weapons/starter_staff_v02.png",
}
SHIELD = "res://assets/art/player/weapons/starter_shield_v02.png"
PROFILE_POS = {"melee": [9, -1], "ranged": [-6, 0], "mage": [3, -10]}
EXPECTED_PAGES = {(s, "none", scale) for s in STATES for scale in (1, 2)} | {
    (s, cls, 2) for s in STATES for cls in CLASS_TEXTURE
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def on_disk(res_path):
    assert res_path.startswith("res://"), res_path
    path = PROJECT / res_path[6:]
    assert path.is_file(), path
    return path


def rgb_img(path):
    image = Image.open(path)
    assert image.size == (640, 360) and image.mode == "RGBA", path
    return np.asarray(image)


manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
assert manifest["display_server"] == "Windows", manifest["display_server"]
assert manifest["project_rendering_method"] == "gl_compatibility"
assert manifest["record_count"] == 50 and len(manifest["pages"]) == 50
assert sha(on_disk(manifest["production_library"])) == manifest["production_library_sha256"]
assert {(p["state"], p["class"], p["zoom"]) for p in manifest["pages"]} == EXPECTED_PAGES

pages = {}
for record in manifest["pages"]:
    key = (record["state"], record["class"], record["zoom"])
    path = on_disk(record["image"])
    assert sha(path) == record["image_sha256"], key
    picture = rgb_img(path)
    assert tuple(record["dimensions"]) == (640, 360)
    assert sha(on_disk(record["source_v03"])) == record["source_v03_sha256"]
    assert sha(on_disk(record["candidate"])) == record["candidate_sha256"]
    pages[key] = {"image": picture, "samples": record["samples"], "path": str(path.relative_to(PROJECT))}

metrics = defaultdict(lambda: {"native_pixels_checked": 0, "native_within_3": 0,
                           "native_exact_alpha255": 0, "native_alpha255_checked": 0,
                           "weapon_delta_pixels": defaultdict(list), "grip_max_distance_px_2x": 0.0,
                           "sample_count": 0})
min_per_frame = 40
for state in STATES:
    for zoom in (1, 2):
        page = pages[(state, "none", zoom)]
        picture = page["image"]
        for sample in page["samples"]:
            frame = sample["frame"]
            revision = sample["revision"]
            texture = on_disk(sample["texture"])
            assert sha(texture) == sample["texture_sha256"]
            source = np.asarray(Image.open(texture).convert("RGBA"))
            assert source.shape[0] == 32 and source.shape[1] % 32 == 0
            assert sample["frame_count"] == source.shape[1] // 32
            pixels = source[:, frame * 32:(frame + 1) * 32]
            pixels = np.repeat(np.repeat(pixels, zoom, axis=0), zoom, axis=1)
            if sample["facing"] == "left":
                pixels = np.flip(pixels, axis=1)
            x = int(sample["player_position_xy"][0]) - 16 * zoom
            y = int(sample["player_position_xy"][1]) - 29 * zoom
            expected = picture[y:y + 32 * zoom, x:x + 32 * zoom, :3]
            assert expected.shape[:2] == pixels.shape[:2], (state, sample)

            # Compare GPU-composited color against exact source RGBA over the
            # verified #3d3d3d viewport background. Near-opaque pixels can
            # differ from raw RGB by more than three due to source alpha.
            near_opaque = pixels[:, :, 3] >= 245
            total = int(np.count_nonzero(near_opaque))
            assert total >= min_per_frame * zoom * zoom, (state, revision, frame, total)
            alpha = pixels[:, :, 3:4].astype(np.float64) / 255.0
            composited = pixels[:, :, :3].astype(np.float64) * alpha + 61.0 * (1.0 - alpha)
            channel_delta = np.abs(expected.astype(np.float64) - composited)
            correct = int(np.count_nonzero(np.all(channel_delta <= 3, axis=2) & near_opaque))
            assert correct == total, (state, revision, sample["facing"], frame, zoom, correct, total)
            fully_opaque = pixels[:, :, 3] == 255
            exact = int(np.count_nonzero(np.all(expected == pixels[:, :, :3], axis=2) & fully_opaque))
            assert exact == int(np.count_nonzero(fully_opaque)), (state, revision, frame, zoom)
            metric = metrics[state]
            metric["native_pixels_checked"] += total
            metric["native_within_3"] += correct
            metric["native_alpha255_checked"] += int(np.count_nonzero(fully_opaque))
            metric["native_exact_alpha255"] += exact
            metric["sample_count"] += 1

            # This is a lower bound on the physical body-to-fixed-grip gap,
            # not an artistic judgment about whether the hand is gripping.
            if revision == "r2_candidate" and zoom == 2:
                ys, xs = np.where(pixels[:, :, 3] >= 160)
                grip = np.array(sample["grip_global_position_xy"], dtype=np.float64)
                distances = np.hypot(xs + x - grip[0], ys + y - grip[1])
                metric["grip_max_distance_px_2x"] = max(metric["grip_max_distance_px_2x"], float(distances.min()))

    for cls in CLASS_TEXTURE:
        page = pages[(state, cls, 2)]
        base = pages[(state, "none", 2)]
        assert len(page["samples"]) == len(base["samples"])
        for sample, baseline in zip(page["samples"], base["samples"]):
            assert sample["frame"] == baseline["frame"]
            assert sample["facing"] == baseline["facing"]
            assert sample["revision"] == baseline["revision"]
            assert sample["texture_sha256"] == baseline["texture_sha256"]
            assert sample["weapon_texture"] == CLASS_TEXTURE[cls]
            assert sample["weapon_position_xy"] == PROFILE_POS[cls]
            assert sample["shield_visible"] == (cls == "melee")
            assert sample["shield_texture"] == (SHIELD if cls == "melee" else "")
            assert sample["body_visual_scale_xy"] == ([-1, 1] if sample["facing"] == "left" else [1, 1])
            center = sample["player_position_xy"]
            grip = sample["grip_global_position_xy"]
            expected_grip = [center[0] + (14 if sample["facing"] == "right" else -14), center[1] - 24]
            assert grip == expected_grip, (state, cls, sample, expected_grip)
            assert sample["weapon_pivot_global_position_xy"] == expected_grip
            expected_rot = 0.0 if sample["facing"] == "right" else np.pi
            assert abs(sample["weapon_pivot_rotation"] - expected_rot) < 0.00001

            # Isolate the actor region to exclude labels. A real sprite from
            # each profile must visibly change rendered pixels near the grip.
            x, y = map(int, center)
            region = (slice(y - 58, y + 8), slice(x - 30, x + 30))
            a = page["image"][region][:, :, :3]
            b = base["image"][region][:, :, :3]
            changed = int(np.count_nonzero(np.any(a != b, axis=2)))
            assert changed > 10, (state, cls, sample["revision"], sample["facing"], sample["frame"], changed)
            metrics[state]["weapon_delta_pixels"][cls].append(changed)

summaries = {}
for state in STATES:
    metric = metrics[state]
    result = {
        "screenshot_native_frame_samples": metric["sample_count"],
        "near_opaque_source_pixels_checked": metric["native_pixels_checked"],
        "near_opaque_screenshot_matches_within_3": metric["native_within_3"],
        "fully_opaque_source_pixels_checked_and_exact": metric["native_exact_alpha255"],
        "class_equipment_delta_min_max": {cls: [min(v), max(v)] for cls, v in metric["weapon_delta_pixels"].items()},
        "candidate_max_nearest_body_to_grip_px_at_2x": round(metric["grip_max_distance_px_2x"], 3),
        "status": "NATIVE_RENDERER_SOURCE_PIXELS_AND_PROFILE_OVERLAY_VERIFIED_VISUAL_APPROVAL_PENDING",
    }
    summaries[state] = result
    print(f"PASS {state:12} body source pixels {result['near_opaque_screenshot_matches_within_3']}/"
          f"{result['near_opaque_source_pixels_checked']} / exact alpha255 "
          f"{result['fully_opaque_source_pixels_checked_and_exact']} / class overlays "
          f"{result['class_equipment_delta_min_max']} / max grip gap "
          f"{result['candidate_max_nearest_body_to_grip_px_at_2x']} px")

report = {
    "schema": "player-r2-real-renderer-verification/v1",
    "capture_manifest": str(MANIFEST.relative_to(PROJECT)),
    "capture_manifest_sha256": sha(MANIFEST),
    "status": "OBJECTIVE_RENDER_VERIFIED_VISUAL_ART_AND_GRIP_APPROVAL_PENDING",
    "criteria": "Each body source pixel alpha>=245 RGB matches actual non-headless screenshot <=3; alpha255 matches exactly; player-profile equipment changes captured pixels in all sampled frames and facings; actual resource/pose hashes and transforms match.",
    "limitations": "Does not prove equipment shape touches the anatomically correct gloved hand; does not prove candidate lacks a connected baked effect or weapon; does not validate candidate frame timing/acceptance.",
    "states": summaries,
}
report_text = json.dumps(report, indent=2) + "\n"
if ARGS.write_report:
    REPORT.write_text(report_text, encoding="utf-8")
else:
    # read_text normalizes this Windows-authored report's CRLF to LF,
    # preserving its exact on-disk bytes in the default check-only path.
    assert REPORT.is_file() and REPORT.read_text(encoding="utf-8") == report_text, (
        "renderer verification has changed; review before explicitly refreshing "
        "with --write-report"
    )
print("PASS 50 real Compatibility captures / 10 states / both directions / 1x,2x and all three starter equipment profiles")
print("REPORT", REPORT.relative_to(PROJECT), "sha256", sha(REPORT))
