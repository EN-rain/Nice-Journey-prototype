"""Read-only verify actual native Player V03 interact versus source-backed R3 split.

The live V03 and R3 review are intentionally DIFFERENT. This is not an acceptance
test that silently treats native screenshot identity as a new production approval.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
OUT = PROJECT / "assets/art/player/animations/review_r3/live_v03_interact_comparison"
DATA = OUT / "player_interact_live_v03_r3_native_evidence.json"
R2 = PROJECT / "assets/art/player/animations/player_body_interact_sheet_v03_r2_candidate.png"
EXPECTED = {(kind, zoom) for kind in ("none", "melee") for zoom in (1, 2)}
COUNT = 5


def disk(resource: str) -> Path:
    assert resource.startswith("res://")
    path = (PROJECT / resource[6:]).resolve()
    assert path.is_relative_to(PROJECT.resolve()) and path.is_file(), path
    return path


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgba(path: Path) -> np.ndarray:
    with Image.open(path) as image:
        return np.asarray(image.convert("RGBA")).copy()


record = json.loads(DATA.read_text(encoding="utf-8"))
assert record["schema"] == "player-interact-live-v03-versus-r3-native-review/v1"
assert record["acceptance"] == "REVIEW_ONLY_NOT_PRODUCTION_OR_ART_ACCEPTED"
assert record["scene"] == "res://src/player/player.tscn"
assert record["rendering_method"] == "gl_compatibility"
assert record["display_server"] == "Windows"
assert record["dimensions"] == [640, 360] and record["frame_count"] == COUNT
assert record["page_count"] == len(record["pages"]) == 4
assert {(p["class"], p["zoom"]) for p in record["pages"]} == EXPECTED
assert sha(disk(record["production_library"])) == record["production_library_sha256"]
for kind in ("source_live", "source_r3_body", "source_r3_vfx"):
    assert sha(disk(record[kind])) == record[kind + "_sha256"]

live = rgba(disk(record["source_live"]))
body = rgba(disk(record["source_r3_body"]))
fx = rgba(disk(record["source_r3_vfx"]))
r2 = rgba(R2)
assert live.shape == body.shape == fx.shape == r2.shape == (32, 160, 4)
assert not np.any((body[:, :, 3] > 0) & (fx[:, :, 3] > 0))
recomposed = body.copy()
recomposed[fx[:, :, 3] > 0] = fx[fx[:, :, 3] > 0]
assert np.array_equal(recomposed, r2), "R3 review is not exact separated V03 R2 source"
original_rgba_differences = int(np.count_nonzero(np.any(live != r2, axis=2)))
assert original_rgba_differences > 0, "No novel live-versus-R3 review needed"
print(f"PASS original LIVE V03 vs R3 composition: {original_rgba_differences} different RGBA source pixels")

native_differing_pixels = 0
verified_opaque_source_pixels = 0
page_pictures = {}
for page in record["pages"]:
    kind, zoom = page["class"], page["zoom"]
    assert page["state"] == "interact" and page["frames"] == COUNT
    assert len(page["samples"]) == 4 * COUNT
    picture_path = disk(page["image"])
    assert sha(picture_path) == page["image_sha256"]
    screenshot = rgba(picture_path)
    assert screenshot.shape == (360, 640, 4)
    page_pictures[(kind, zoom)] = screenshot
    samples = {(s["facing"], s["revision"], s["frame"]): s for s in page["samples"]}
    assert len(samples) == 4 * COUNT
    page_differing = 0
    for facing in ("right", "left"):
        for frame in range(COUNT):
            a = samples[(facing, "live_v03", frame)]
            b = samples[(facing, "r3_body_and_source_sparks", frame)]
            assert a["row"] in (0, 2) and b["row"] == a["row"] + 1
            assert a["body_frame"] == b["body_frame"] == frame
            assert a["body_hframes"] == b["body_hframes"] == COUNT
            assert a["body_visual_scale"] == b["body_visual_scale"] == (
                [-1.0, 1.0] if facing == "left" else [1.0, 1.0]
            )
            assert a["body_path"] == record["source_live"]
            assert b["body_path"] == record["source_r3_body"]
            assert a["effect_path"] == "" and a["effect_sha256"] == ""
            assert b["effect_path"] == record["source_r3_vfx"]
            assert a["body_sha256"] == record["source_live_sha256"]
            assert b["body_sha256"] == record["source_r3_body_sha256"]
            assert b["effect_sha256"] == record["source_r3_vfx_sha256"]
            assert a["player_xy"][0] == b["player_xy"][0] == 170 + 64 * frame
            assert b["player_xy"][1] - a["player_xy"][1] == 72
            x = round(a["player_xy"][0]) - 16 * zoom
            y0 = round(a["player_xy"][1]) - 29 * zoom
            y1 = round(b["player_xy"][1]) - 29 * zoom
            size = 32 * zoom
            actual_a = screenshot[y0:y0 + size, x:x + size]
            actual_b = screenshot[y1:y1 + size, x:x + size]
            assert actual_a.shape == actual_b.shape == (size, size, 4)
            page_differing += int(np.count_nonzero(np.any(actual_a != actual_b, axis=2)))
            if kind == "none":
                for source, actual in ((live, actual_a), (r2, actual_b)):
                    cell = source[:, frame * 32:(frame + 1) * 32]
                    if facing == "left":
                        cell = cell[:, ::-1]
                    cell = np.repeat(np.repeat(cell, zoom, axis=0), zoom, axis=1)
                    opaque = cell[:, :, 3] >= 245
                    assert int(opaque.sum()) >= 40 * zoom * zoom
                    alpha = cell[:, :, 3:4] / 255.0
                    expected = cell[:, :, :3] * alpha + 61.0 * (1.0 - alpha)
                    # Native 2x GL alpha blending of the existing live V03
                    # reaches 3.6275 RGB units; this bounded tolerance is
                    # measured, not an art/pose-similarity threshold.
                    within = np.all(np.abs(actual[:, :, :3].astype(float) - expected) <= 4, axis=2)
                    assert np.all(within[opaque]), (kind, zoom, facing, frame, "native source pixels differ")
                    verified_opaque_source_pixels += int(opaque.sum())
    assert page_differing > 0, (kind, zoom, "live V03 vs R3 unexpectedly visually identical")
    native_differing_pixels += page_differing
    print(f"PASS native {kind} {zoom}x right/left five frames: {page_differing} screenshot pixels differ")

for zoom in (1, 2):
    none = page_pictures[("none", zoom)]
    melee = page_pictures[("melee", zoom)]
    assert int(np.count_nonzero(np.any(none != melee, axis=2))) > 0, (
        zoom, "actual configured melee equipment must differ from no-equipment capture"
    )
print(
    f"PASS 4 native GL pages, {native_differing_pixels} live-versus-R3 screenshot pixel differences, "
    f"{verified_opaque_source_pixels} independent near-opaque source-pixel matches; "
    "NO art/timing or production acceptance implied"
)
