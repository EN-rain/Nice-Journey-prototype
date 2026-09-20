"""Fail-closed disconnected-effect audit for immutable V04 R2 player candidates.

At alpha >= 24 each source-backed 32px frame must have one 8-connected body
component and no detached island, not even one pixel. This proves only that
R3's *detached-component* separation method cannot remove these six states'
remaining connected marks; it does not assert subjective art quality or rule
out later manually reviewed, source-backed surgical edits.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
ANIMATIONS = ROOT / "assets/art/player/animations"
PROVENANCE = ROOT / "assets/art/generated_sources/imagegen/player/body_only_v04/player_body_only_v04_r2_candidate_manifest.json"
STATES = ("attack", "heavy_attack", "block", "parry", "cast", "hit")


def sha(file: Path) -> str:
    return hashlib.sha256(file.read_bytes()).hexdigest()


manifest = json.loads(PROVENANCE.read_text(encoding="utf-8"))
assert manifest["schema"] == "player-body-only-v04-r2-candidate/v1"
records = {record["state"]: record for record in manifest["records"]}
assert set(STATES) == set(records), "V04 R2 source identities changed"
total = 0

for state in STATES:
    record = records[state]
    filename = ROOT / record["output"].removeprefix("res://")
    original = ROOT / record["source"].removeprefix("res://")
    assert filename == ANIMATIONS / f"player_body_{state}_sheet_v04_r2_candidate.png"
    assert sha(original) == record["source_sha256"], (state, "immutable source changed")
    assert sha(filename) == record["output_sha256"], (state, "R2 derivative changed")
    image = np.asarray(Image.open(filename).convert("RGBA"))
    if image.shape[0] != 32 or image.shape[1] % 32 or [image.shape[1], image.shape[0]] != record["output_dimensions"]:
        raise ValueError(f"wrong 32px sheet geometry: {filename}")
    # Block has 3 selected poses from 7 source poses; hit has 5 from 6.
    # Do not silently pad either source to pretend runtime completeness.
    assert image.shape[1] // 32 == len(record["selected_source_frames"])
    for frame in range(image.shape[1] // 32):
        cell = image[:, frame * 32:(frame + 1) * 32]
        labels, count = ndimage.label(cell[:, :, 3] >= 24, structure=np.ones((3, 3)))
        low_alpha = int(np.count_nonzero((cell[:, :, 3] > 0) & (cell[:, :, 3] < 24)))
        assert count == 1 and low_alpha == 0, (state, frame, count, low_alpha)
        pixels = int(np.count_nonzero(labels))
        assert pixels >= 200, (state, frame, "incomplete silhouette", pixels)
        total += 1
    print(f"PASS {state}: generated-source/R2 hashes, {image.shape[1] // 32} frames, "
          "exactly one connected foreground region per frame; 0 detachable islands")

assert total == 33, total
print("PASS V04 R2 detached-component audit: 33 source-backed frames / 6 states; "
      "no disconnected VFX eligible for mechanical separation; all review-only")
