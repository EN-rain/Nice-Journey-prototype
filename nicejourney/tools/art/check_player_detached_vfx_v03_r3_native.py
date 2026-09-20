"""Read-only native GL screenshot verification of R2 vs R3-body-plus-VFX.

Uses exact scene-captured frame rectangles, not a Python compositing mock.
Identical screenshots do not grant artistic or live timing approval.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "assets/art/player/animations/review_r3/engine/player_r3_native_evidence.json"
EXPECTED = {(s, kind, scale) for s in ("interact", "use_item")
            for kind in ("none", "melee") for scale in (1, 2)}


def disk(resource: str) -> Path:
    assert resource.startswith("res://")
    result = (ROOT / resource[6:]).resolve()
    assert result.is_relative_to(ROOT.resolve()) and result.is_file(), result
    return result


def sha(file: Path) -> str:
    return hashlib.sha256(file.read_bytes()).hexdigest()


record = json.loads(DATA.read_text(encoding="utf-8"))
assert record["schema"] == "player-detached-vfx-r3-native-review/v1"
assert record["acceptance"] == "DIAGNOSTIC_ONLY_NOT_RUNTIME_BOUND_OR_ART_ACCEPTED"
assert record["display_server"] == "Windows"
assert record["rendering_method"] == "gl_compatibility"
assert record["page_count"] == 8 and len(record["pages"]) == 8
assert sha(disk(record["production_library"])) == record["production_library_sha256"]
assert {(p["state"], p["class"], p["zoom"]) for p in record["pages"]} == EXPECTED

compared_pixels = 0
opaque_verified = 0
for page in record["pages"]:
    state, kind, scale = page["state"], page["class"], page["zoom"]
    frames = 5 if state == "interact" else 7
    assert page["frames"] == frames and len(page["samples"]) == frames * 4
    image_file = disk(page["image"])
    assert sha(image_file) == page["image_sha256"]
    with Image.open(image_file) as image:
        assert image.size == (640, 360) and image.mode == "RGBA"
        picture = np.asarray(image).copy()
    samples = {(s["facing"], s["revision"], s["frame"]): s for s in page["samples"]}
    assert len(samples) == len(page["samples"])
    for facing in ("right", "left"):
        for frame in range(frames):
            origin = samples[(facing, "r2_original", frame)]
            split = samples[(facing, "r3_plus_detached_effect", frame)]
            assert origin["body_frame"] == split["body_frame"] == frame
            assert origin["body_hframes"] == split["body_hframes"] == frames
            assert origin["zoom"] == split["zoom"] == scale
            assert origin["body_visual_scale"] == split["body_visual_scale"] == (
                [-1.0, 1.0] if facing == "left" else [1.0, 1.0])
            assert origin["body_sha256"] == page["r2_sha256"]
            assert split["body_sha256"] == page["r3_body_sha256"]
            assert split["effect_sha256"] == page["r3_effect_sha256"]
            assert origin["effect_path"] == "" and origin["effect_sha256"] == ""
            assert sha(disk(origin["body_path"])) == origin["body_sha256"]
            assert sha(disk(split["body_path"])) == split["body_sha256"]
            assert sha(disk(split["effect_path"])) == split["effect_sha256"]
            assert origin["row"] in (0, 2) and split["row"] == origin["row"] + 1
            assert origin["player_xy"][0] == split["player_xy"][0] == 170 + 64 * frame
            assert split["player_xy"][1] - origin["player_xy"][1] == 72
            side = 32 * scale
            x = round(origin["player_xy"][0]) - 16 * scale
            y0 = round(origin["player_xy"][1]) - 29 * scale
            y1 = round(split["player_xy"][1]) - 29 * scale
            a = picture[y0:y0 + side, x:x + side]
            b = picture[y1:y1 + side, x:x + side]
            assert a.shape == b.shape == (side, side, 4)
            assert np.array_equal(a, b), (state, kind, scale, facing, frame,
                                          "real GL R2 vs separately composited R3 pixel mismatch",
                                          int(np.count_nonzero(np.any(a != b, axis=2))))
            compared_pixels += side * side
            if kind == "none":
                with Image.open(disk(origin["body_path"])) as src_image:
                    source = np.asarray(src_image.convert("RGBA"))[:, frame * 32:(frame + 1) * 32]
                if facing == "left":
                    source = source[:, ::-1]
                source = np.repeat(np.repeat(source, scale, axis=0), scale, axis=1)
                near_opaque = source[:, :, 3] >= 245
                assert int(near_opaque.sum()) >= 40 * scale * scale
                alpha = source[:, :, 3:4] / 255.0
                expected = source[:, :, :3] * alpha + 61.0 * (1.0 - alpha)
                good = np.all(np.abs(a[:, :, :3].astype(float) - expected) <= 3, axis=2)
                assert np.all(good[near_opaque]), (state, scale, facing, frame, "R2 source screenshot mismatch")
                opaque_verified += int(near_opaque.sum())
    print(f"PASS native {state} {kind} {scale}x: R2 == real-player R3 body+VFX right/left frames={frames}")

print(f"PASS 8 real GL Compatibility pages; {compared_pixels} full RGBA screenshot pixels identical; "
      f"{opaque_verified} near-opaque source pixels independently verified; art approval pending")
