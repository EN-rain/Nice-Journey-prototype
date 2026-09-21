#!/usr/bin/env python3
"""Check actual native escort review captures against the transferred derivative.

Review-only evidence: this neither inspects original ImageGen source provenance
nor accepts gameplay art, chooses final animation timing, or edits any asset.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent / "engine/escort_animation_candidate_native_evidence.json"
STATIC = PROJECT / "assets/art/npc/escort_anchor_v01.png"
STATIC_SHA256 = "2cfa01c99e1716c168a69aff61cda8593c9ebac7e06e4ba39aa23d764aafd84e"
LIVE_PROFILE = PROJECT / "src/world/npc/presentation/profiles/temporary_escort.tres"
MAX_RGB_DELTA = 8
ALPHA_MIN = 245


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local_path(res: str) -> Path:
    if not res.startswith("res://"):
        raise ValueError(f"Invalid resource path: {res}")
    candidate = (PROJECT / res.removeprefix("res://")).resolve()
    if not candidate.is_relative_to(PROJECT.resolve()) or not candidate.is_file():
        raise ValueError(f"Review evidence references a missing/outside file: {res}")
    return candidate


def verify() -> None:
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    assert evidence["status"] == "REVIEW_ONLY_UNACCEPTED_NOT_LIVE"
    assert digest(STATIC) == evidence["static_sha256"] == STATIC_SHA256
    assert digest(LIVE_PROFILE) == evidence["live_profile_sha256"]
    assert "animation_library" not in LIVE_PROFILE.read_text(encoding="utf-8")
    atlas_path = local_path(evidence["derivative"])
    assert digest(atlas_path) == evidence["derivative_sha256"]
    assert len(evidence["pages"]) == 4
    total_pixels = 0
    max_deviation = 0
    checked_pages: set[tuple[str, int]] = set()
    with Image.open(atlas_path) as atlas:
        atlas.load()
        assert atlas.mode == "RGBA" and atlas.size == (320, 32)
        for page in evidence["pages"]:
            state = page["state"]
            zoom = page["zoom"]
            assert state in ("idle", "walk") and zoom in (1, 2)
            assert (state, zoom) not in checked_pages
            checked_pages.add((state, zoom))
            count = 4 if state == "idle" else 6
            first = 0 if state == "idle" else 4
            assert len(page["samples"]) == 2 * count
            image_path = local_path(page["image"])
            assert digest(image_path) == page["image_sha256"]
            matched = set()
            with Image.open(image_path) as capture:
                capture.load()
                assert capture.size == (640, 360)
                rendered = capture.convert("RGB")
                for sample in page["samples"]:
                    frame = sample["frame"]
                    direction = sample["direction"]
                    assert direction in ("right", "left")
                    assert frame in range(first, first + count)
                    assert sample["zoom"] == zoom
                    assert sample["flip_h"] == (direction == "left")
                    assert (frame, direction) not in matched
                    matched.add((frame, direction))
                    x_anchor, y_anchor = map(int, sample["anchor_xy"])
                    tile = atlas.crop((frame * 32, 0, (frame + 1) * 32, 32))
                    if direction == "left":
                        tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    for y in range(32):
                        for x in range(32):
                            red, green, blue, alpha = tile.getpixel((x, y))
                            if alpha < ALPHA_MIN:
                                continue
                            for dy in range(zoom):
                                for dx in range(zoom):
                                    screen_x = x_anchor + (x - 16) * zoom + dx
                                    screen_y = y_anchor + (y - 29) * zoom + dy
                                    actual = rendered.getpixel((screen_x, screen_y))
                                    deviation = max(abs(actual[0] - red), abs(actual[1] - green), abs(actual[2] - blue))
                                    max_deviation = max(max_deviation, deviation)
                                    assert deviation <= MAX_RGB_DELTA, (
                                        f"{state} {zoom}x {direction} frame {frame}: "
                                        f"pixel ({x},{y}) RGB deviation {deviation}"
                                    )
                                    total_pixels += 1
    assert checked_pages == {("idle", 1), ("idle", 2), ("walk", 1), ("walk", 2)}
    assert total_pixels > 10000, "Missing/empty sprite pixels in GL evidence"
    print(
        f"ESCORT NATIVE REVIEW PIXEL PASS: pages=4 samples=40 "
        f"source_pixels={total_pixels} max_rgb_delta={max_deviation}/8 "
        f"candidate_sha256={evidence['derivative_sha256']} "
        "REVIEW_ONLY_NOT_ACCEPTED"
    )


if __name__ == "__main__":
    verify()
