"""Independent PNG/source/pose regression checks for isolated player V04 R2."""

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


PROJECT = Path(__file__).resolve().parents[2]
MANIFEST = PROJECT / "assets/art/generated_sources/imagegen/player/body_only_v04/player_body_only_v04_r2_candidate_manifest.json"
SOURCE_ROOT = PROJECT / "assets/art/generated_sources/imagegen/player/body_only_v04"
ROOT = PROJECT / "assets/art/player/animations"
records = json.loads(MANIFEST.read_text(encoding="utf-8"))["records"]
assert [r["state"] for r in records] == ["attack", "heavy_attack", "block", "parry", "cast", "hit"]
assert len({r["output_sha256"] for r in records}) == 6
for record in records:
    source = SOURCE_ROOT / record["source"].rsplit("/", 1)[-1]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == record["source_sha256"]
    path = ROOT / record["output"].rsplit("/", 1)[-1]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record["output_sha256"]
    im = Image.open(path)
    assert im.mode == "RGBA" and im.size == tuple(record["output_dimensions"])
    assert im.size == (32 * len(record["frames"]), 32)
    for index, meta in enumerate(record["frames"]):
        rgba = np.asarray(im.crop((32 * index, 0, 32 * (index + 1), 32)))
        ys, xs = np.where(rgba[:, :, 3] != 0)
        assert len(xs) > 30, (record["state"], index, "empty frame")
        assert (int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)) == tuple(meta["output_alpha_bbox_xyxy"])
        assert ys.max() == 29, (record["state"], index, "ground baseline")
        assert not np.any(rgba[rgba[:, :, 3] == 0, :3]), (record["state"], index, "RGB in transparent padding")
        assert meta["scaled_size"][0] <= 32 and meta["scaled_size"][1] <= 32
    print(f"PASS {record['state']}: {len(record['frames'])} frames, dimensions={im.size}, source and output hashes match, baseline y29, transparent padding clean")

by_state = {r["state"]: r for r in records}
assert [f["source_frame"] for f in by_state["block"]["frames"]] == [2, 3, 4]
assert [f["source_frame"] for f in by_state["hit"]["frames"]] == [1, 2, 3, 4, 5]
assert by_state["hit"]["frames"][3]["scaled_size"][1] <= 22  # crouch stays crouched
assert by_state["hit"]["frames"][0]["scaled_size"][1] >= 27
assert by_state["attack"]["frames"][3]["alpha_crop_xyxy"][2] < 1447
assert by_state["attack"]["frames"][4]["alpha_crop_xyxy"][0] < 1447  # neighbor fragment belongs to frame 4
assert by_state["block"]["frames"][2]["alpha_crop_xyxy"][0] == 1240  # source block frame 4 crosses old cell
assert by_state["attack"]["discarded_disconnected_threshold_pixels"] <= 2
assert by_state["block"]["discarded_disconnected_threshold_pixels"] <= 4
print("PASS six-state/pose regression: complete-body crops, source frame selection, crouch scale and boundary ownership")
