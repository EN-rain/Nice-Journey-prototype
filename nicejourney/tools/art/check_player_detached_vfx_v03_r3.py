"""Independent read-only pixel gate for the two non-production R3 splits.

This intentionally does not call the derivation script. It audits the persisted
PNG bytes, generated-source identity, frame ownership, and exact RGBA restoration.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "assets/art/player/animations/review_r3"
MANIFEST = REVIEW / "player_detached_vfx_v03_r3_candidate_manifest.json"
EXPECTED = {"interact": (5, 2, 10), "use_item": (7, 5, 10)}


def path(res: str) -> Path:
    assert res.startswith("res://"), res
    value = (ROOT / res[6:]).resolve()
    assert value.is_relative_to(ROOT.resolve()) and value.is_file(), value
    return value


def digest(file: Path) -> str:
    return hashlib.sha256(file.read_bytes()).hexdigest()


def rgba(file: Path, dimensions: tuple[int, int]) -> np.ndarray:
    with Image.open(file) as image:
        assert image.format == "PNG" and image.mode == "RGBA", file
        assert image.size == dimensions, (file, image.size, dimensions)
        return np.asarray(image).copy()


data = json.loads(MANIFEST.read_text(encoding="utf-8"))
assert data["schema"] == "player-detached-vfx-v03-r3-candidate/v1"
assert data["acceptance"] == "CANDIDATE_ONLY_SOURCE_EXACT_NOT_RUNTIME_BOUND"
assert len(data["records"]) == len(EXPECTED)
assert {rec["state"] for rec in data["records"]} == set(EXPECTED)

for rec in data["records"]:
    state = rec["state"]
    frames, effect_frame, effect_pixels = EXPECTED[state]
    assert rec["frame_count"] == frames and rec["canvas"] == [frames * 32, 32]
    assert len(rec["detached_components"]) == 1
    assert rec["detached_components"][0]["frame"] == effect_frame
    assert rec["detached_components"][0]["pixels"] == effect_pixels
    for role in ("source_original", "source_r2", "body_candidate", "vfx_candidate"):
        image_path = path(rec[role])
        assert digest(image_path) == rec[role + "_sha256"], (state, role)
    orig = rgba(path(rec["source_r2"]), (frames * 32, 32))
    body = rgba(path(rec["body_candidate"]), (frames * 32, 32))
    effect = rgba(path(rec["vfx_candidate"]), (frames * 32, 32))

    body_present = body[:, :, 3] != 0
    effect_present = effect[:, :, 3] != 0
    assert not np.any(body_present & effect_present), (state, "overlapping alpha")
    assert np.all(body[~body_present] == 0), (state, "invisible body RGB")
    assert np.all(effect[~effect_present] == 0), (state, "invisible effect RGB")
    assert np.array_equal(body[body_present], orig[body_present]), (state, "modified body")
    assert np.array_equal(effect[effect_present], orig[effect_present]), (state, "modified effect")
    restored = body.copy()
    restored[effect_present] = effect[effect_present]
    assert np.array_equal(restored, orig), (state, "failed full RGBA recomposition")
    per_frame = [int(effect_present[:, n * 32:(n + 1) * 32].sum()) for n in range(frames)]
    assert per_frame == [effect_pixels if n == effect_frame else 0 for n in range(frames)], (state, per_frame)
    diff = np.any(body != orig, axis=2)
    assert np.array_equal(diff, effect_present), (state, "unexpected body pixel change")
    # The recorded component bounds use local-frame x-coordinates and half-open boxes.
    local = effect_present[:, effect_frame * 32:(effect_frame + 1) * 32]
    ys, xs = np.nonzero(local)
    assert xs.size == effect_pixels
    for xmin, ymin, xmax, ymax in rec["detached_components"][0]["source_component_bounds"]:
        assert bool(local[ymin:ymax, xmin:xmax].any()), (state, "missing component")
    print(f"PASS {state}: source hashes, {frames} cells, disjoint ownership, "
          f"{per_frame}, exact full-sheet RGBA recomposition")

print("PASS independent player R3 audit: 2 review-only states; no runtime acceptance")
