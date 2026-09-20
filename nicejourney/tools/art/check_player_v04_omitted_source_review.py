"""Read-only source and actual Windows GL checks of unselected V04 poses.

The source frame is compared with a real Player-scene viewport; equipment pages
must also visibly differ from no-equipment pages. This is NOT art acceptance.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/player/animations/review_v04_full_source"
SOURCE = OUT / "player_v04_full_source_pose_review_manifest.json"
NATIVE = OUT / "engine/player_v04_full_source_native_evidence.json"
COUNTS = {"block": 7, "hit": 6}
PAGES = {(state, kind, zoom) for state in COUNTS
         for kind in ("none", "melee") for zoom in (1, 2)}


def file(resource: str) -> Path:
    assert resource.startswith("res://"), resource
    candidate = (ROOT / resource[6:]).resolve()
    assert candidate.is_relative_to(ROOT.resolve()) and candidate.is_file(), candidate
    return candidate


def sha(source: Path) -> str:
    return hashlib.sha256(source.read_bytes()).hexdigest()


def rgba(source: Path, expected: tuple[int, int]) -> np.ndarray:
    with Image.open(source) as image:
        assert image.format == "PNG" and image.mode == "RGBA", source
        assert image.size == expected, (source, image.size, expected)
        return np.asarray(image).copy()


source = json.loads(SOURCE.read_text(encoding="utf-8"))
assert source["schema"] == "player-v04-omitted-source-pose-review/v1"
assert source["acceptance"] == "REVIEW_ONLY_NOT_VISUALLY_ACCEPTED_NOT_RUNTIME_BOUND"
assert source["no_padding_or_synthetic_interpolation"] is True
assert {r["state"] for r in source["records"]} == set(COUNTS)

frames = {}
for record in source["records"]:
    state, count = record["state"], COUNTS[record["state"]]
    assert record["original_source_pose_count"] == count
    assert sha(file(record["original_generated_source"])) == record["original_generated_source_sha256"]
    assert sha(file(record["r2_candidate"])) == record["r2_candidate_sha256"]
    assert sha(file(record["full_source_review"])) == record["full_source_review_sha256"]
    assert record["status"] == "SOURCE_EXACT_CANDIDATE_UNREVIEWED_NOT_PRODUCTION_OR_LIVE"
    original = rgba(file(record["r2_candidate"]), (len(record["r2_selected_source_indices_verified_exact"]) * 32, 32))
    full = rgba(file(record["full_source_review"]), (count * 32, 32))
    selected = record["r2_selected_source_indices_verified_exact"]
    omitted = record["newly_exposed_source_indices_unapproved"]
    assert len(set(selected)) == len(selected)
    assert sorted(selected + omitted) == list(range(count))
    expected_indices = ([2, 3, 4], [0, 1, 5, 6]) if state == "block" else ([1, 2, 3, 4, 5], [0])
    assert (selected, omitted) == expected_indices, state
    hashes = []
    for frame in range(count):
        pixel = full[:, frame * 32:(frame + 1) * 32]
        assert int(np.count_nonzero(pixel[:, :, 3] >= 24)) >= 200, (state, frame)
        assert not np.any(pixel[0, :, 3]) and not np.any(pixel[-1, :, 3])
        assert not np.any(pixel[:, 0, 3]) and not np.any(pixel[:, -1, 3])
        hashes.append(hashlib.sha256(pixel.tobytes()).hexdigest())
    assert hashes == record["frame_rgba_sha256"]
    assert len(set(hashes)) == count and record["identical_frame_pairs"] == [], state
    # Pixel hashes alone cannot distinguish real source pose changes from a
    # one-pixel color-noise variant. Check every pair's full RGBA and alpha
    # silhouette, while still leaving artistic motion quality unapproved.
    pair_differences = []
    for first in range(count):
        a = full[:, first * 32:(first + 1) * 32]
        for second in range(first + 1, count):
            b = full[:, second * 32:(second + 1) * 32]
            changed = int(np.count_nonzero(np.any(a != b, axis=2)))
            silhouette_changed = int(np.count_nonzero((a[:, :, 3] != 0) ^ (b[:, :, 3] != 0)))
            assert changed >= 128 and silhouette_changed >= 12, (state, first, second, changed, silhouette_changed)
            pair_differences.append((changed, silhouette_changed))
    for slot, index in enumerate(selected):
        assert np.array_equal(original[:, slot * 32:(slot + 1) * 32], full[:, index * 32:(index + 1) * 32]), (state, index)
    frames[state] = full
    print(f"PASS {state}: {count} genuine-source derivatives, {len(omitted)} previously omitted; "
          f"minimum pair differences RGBA/silhouette "
          f"{min(d[0] for d in pair_differences)}/{min(d[1] for d in pair_differences)}; "
          "selected R2 frames unchanged")

native = json.loads(NATIVE.read_text(encoding="utf-8"))
assert native["schema"] == "player-v04-full-source-native-review/v1"
assert native["acceptance"] == "CANDIDATE_ONLY_SOURCE_POSES_NOT_ART_APPROVED_NOT_LIVE"
assert native["display_server"] == "Windows" and native["renderer"] == "gl_compatibility"
assert native["viewport"] == [640, 360] and native["background_rgb"] == [61, 61, 61]
assert sha(file(native["live_library"])) == native["live_library_sha256"]
assert native["page_count"] == 8 and len(native["pages"]) == 8
assert {(page["state"], page["class"], page["zoom"]) for page in native["pages"]} == PAGES

pages = {}
matches = 0
worst_near_opaque = 0.0
fully_opaque_matches = 0
for page in native["pages"]:
    state, kind, zoom = page["state"], page["class"], page["zoom"]
    assert page["frames"] == COUNTS[state]
    record = next(r for r in source["records"] if r["state"] == state)
    assert page["texture"] == record["full_source_review"]
    assert page["texture_sha256"] == record["full_source_review_sha256"]
    path = file(page["image"])
    assert sha(path) == page["image_sha256"]
    screenshot = rgba(path, (640, 360))
    assert len(page["samples"]) == COUNTS[state] * 2
    samples = {}
    for sample in page["samples"]:
        frame, facing = sample["frame"], sample["facing"]
        assert facing in ("left", "right") and 0 <= frame < COUNTS[state]
        assert sample["body_frame"] == frame and sample["body_hframes"] == COUNTS[state]
        assert sample["player_xy"] == [170.0 + frame * 64, 240.0 if facing == "left" else 100.0]
        assert sample["body_visual_scale"] == ([-1.0, 1.0] if facing == "left" else [1.0, 1.0])
        key = (facing, frame)
        assert key not in samples
        samples[key] = sample
        if kind != "none":
            continue
        expected = frames[state][:, frame * 32:(frame + 1) * 32]
        if facing == "left":
            expected = expected[:, ::-1]
        expected = np.repeat(np.repeat(expected, zoom, axis=0), zoom, axis=1)
        x = int(sample["player_xy"][0]) - 16 * zoom
        y = int(sample["player_xy"][1]) - 29 * zoom
        rendered = screenshot[y:y + 32 * zoom, x:x + 32 * zoom, :3]
        assert rendered.shape == (32 * zoom, 32 * zoom, 3)
        opaque = expected[:, :, 3] >= 245
        assert int(opaque.sum()) >= 40 * zoom * zoom
        alpha = expected[:, :, 3:4].astype(float) / 255.0
        composite = expected[:, :, :3].astype(float) * alpha + 61 * (1 - alpha)
        delta = np.abs(rendered.astype(float) - composite)
        worst_near_opaque = max(worst_near_opaque, float(delta[opaque].max()))
        full = expected[:, :, 3] == 255
        if full.any():
            # Imported GL render is *exact* at every fully opaque pixel; the
            # source file itself is separately byte-verified above.
            assert np.array_equal(rendered[full], expected[:, :, :3][full]), (state, facing, frame, zoom, "opaque RGB")
            fully_opaque_matches += int(full.sum())
        # Measured Godot partially transparent (alpha 245–254) compositing
        # deviates by up to 7.8824 RGB; 8 is a bounded observed native render
        # tolerance, NOT an allowance to mutate the source or opaque pixels.
        assert np.all(delta[opaque] <= 8), (state, facing, frame, zoom, "near-opaque RGB")
        matches += int(opaque.sum())
    assert len(samples) == COUNTS[state] * 2
    pages[(state, kind, zoom)] = screenshot
    print(f"PASS GL {state} {kind} {zoom}x: real Player scene, {COUNTS[state]} source frames each facing")

overlay_count = 0
for state in COUNTS:
    for zoom in (1, 2):
        baseline = pages[(state, "none", zoom)]
        equipped = pages[(state, "melee", zoom)]
        for facing, y in (("right", 100), ("left", 240)):
            for frame in range(COUNTS[state]):
                x = 170 + frame * 64
                region = (slice(y - 58 * zoom // 2, y + 8), slice(x - 30, x + 30))
                different = int(np.count_nonzero(np.any(baseline[region][:, :, :3] != equipped[region][:, :, :3], axis=2)))
                assert different > 10, (state, zoom, facing, frame, different)
                overlay_count += 1

assert overlay_count == 52
print(f"PASS V04 full-source native gate: 8 actual GL pages, {matches} near-opaque source pixels, "
      f"{fully_opaque_matches} exact fully opaque source pixels, max near-opaque RGB delta "
      f"{worst_near_opaque:.4f}/8, {overlay_count} real equipment overlays; five omitted source poses exposed, none art-approved")
