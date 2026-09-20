"""Verify all 17 player art states against recorded sources and live bindings.

No production write, reclassification or visual approval is performed here.
Source/derivative hashes and PNG geometry are necessary, not sufficient, for
actual renderer acceptance and separate starter-weapon hand alignment.
"""

import hashlib
import json
from pathlib import Path
import re

import numpy as np
from PIL import Image


PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT.parent
PLAYER = PROJECT / "assets/art/player/animations"
V03_SOURCE = PROJECT / "assets/art/generated_sources/imagegen/player/main_character_batches_v03"
V04_SOURCE = PROJECT / "assets/art/generated_sources/imagegen/player/body_only_v04"
NEAREST = PROJECT / "docs/evidence/art/nearest_candidates/player_main_character_v03_nearest_derivation_manifest.json"
ORIGINAL = V03_SOURCE / "player_main_character_v03_derivation_manifest.json"
HANDOFF = ROOT / "Nice_Journey_Asset_Handoff_Manifest.json"
R2_FOUR = V03_SOURCE / "player_remaining_v03_r2_candidate_manifest.json"
R2_SIX = V04_SOURCE / "player_body_only_v04_r2_candidate_manifest.json"
SCENE = PROJECT / "src/player/player.tscn"
LIBRARY = PROJECT / "src/player/presentation/player_body_animation_library.tres"
NEAREST_SEVEN = {"idle", "walk", "run", "dash", "climb", "pickup", "sleep"}
R2_SIX_STATES = {"attack", "heavy_attack", "block", "parry", "cast", "hit"}
R2_FOUR_STATES = {"death", "dodge", "interact", "use_item"}
ALL = NEAREST_SEVEN | R2_SIX_STATES | R2_FOUR_STATES


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_geometry(path, frames):
    image = Image.open(path)
    assert image.mode == "RGBA" and image.size == (frames * 32, 32), (path, image.mode, image.size)
    for frame in range(frames):
        array = np.asarray(image.crop((frame * 32, 0, (frame + 1) * 32, 32)))
        ys, xs = np.where(array[:, :, 3] != 0)
        assert len(xs) > 30, (path, frame, "empty")
        assert max(xs) <= 31 and max(ys) <= 31, (path, frame, "clipped")
    return image.size


nearest = json.loads(NEAREST.read_text(encoding="utf-8"))
original = json.loads(ORIGINAL.read_text(encoding="utf-8"))
four = json.loads(R2_FOUR.read_text(encoding="utf-8"))
six = json.loads(R2_SIX.read_text(encoding="utf-8"))
assert set(nearest["animations"]) == ALL
assert set(original["animations"]) == ALL
assert {r["state"] for r in four["records"]} == R2_FOUR_STATES
assert {r["state"] for r in six["records"]} == R2_SIX_STATES
assert "player_body_animation_library.tres" in SCENE.read_text(encoding="utf-8")
assert "player_body_animation_library_v04.tres" not in SCENE.read_text(encoding="utf-8")
resource = LIBRARY.read_text(encoding="utf-8")
asset_records = {record["stable_asset_id"]: record for record in json.loads(HANDOFF.read_text(encoding="utf-8"))["assets"]}
paths = set(re.findall(r'path="(res://assets/art/player/animations/player_body_[^\"]+\.png)"', resource))
expected_paths = {f"res://assets/art/player/animations/player_body_{s}_sheet_v03.png" for s in ALL}
assert paths == expected_paths, ("runtime texture bindings differ", paths ^ expected_paths)

for source, identity in nearest["sources"].items():
    path = V03_SOURCE / "exact_sources" / source
    assert sha(path) == identity["sha256"], (source, "source SHA mismatch")
    assert list(Image.open(path).size) == identity["dimensions"]
for entry in six["records"]:
    source = PROJECT / entry["source"].removeprefix("res://")
    assert sha(source) == entry["source_sha256"]

candidate_entries = {r["state"]: r for r in six["records"] + four["records"]}
for name, record in nearest["animations"].items():
    filename = f"player_body_{name}_sheet_v03.png"
    actual = sha(PLAYER / filename)
    nearest_hash = record["output_sha256"]
    original_hash = original["animations"][name]["output_sha256"]
    if name in NEAREST_SEVEN:
        assert actual == nearest_hash and actual != original_hash, (name, "accepted nearest changed")
        record_id = f"asset:player/animations/player_body_{name}_sheet"
        assert asset_records[record_id]["classification"] == "ACCEPTED_DO_NOT_REGENERATE"
        assert asset_records[record_id]["verified_evidence"]["sha256"] == nearest_hash
        category = "LIVE_V03_NEAREST_SOURCE_RUNTIME_ACCEPTED"
    else:
        assert actual == original_hash and actual != nearest_hash, (name, "live original changed")
        assert asset_records[f"asset:player/animations/player_body_{name}_sheet"]["classification"] == "EXISTS_NEEDS_REVISION"
        category = "LIVE_V03_LANCZOS_R2_STAGED"
    assert png_geometry(PLAYER / filename, record["frame_count"]) == tuple(record["output_dimensions"])
    if name in candidate_entries:
        entry = candidate_entries[name]
        path = PROJECT / entry["output"].removeprefix("res://")
        assert sha(path) == entry["output_sha256"], (name, "staged candidate changed")
        assert png_geometry(path, len(entry["frames"])) == tuple(entry["output_dimensions"])
        for i, frame in enumerate(entry["frames"]):
            rgba = np.asarray(Image.open(path).crop((i * 32, 0, (i + 1) * 32, 32)))
            ys, xs = np.where(rgba[:, :, 3] > 0)
            assert max(ys) == 29, (name, i, "ground anchor")
            assert np.count_nonzero(rgba[rgba[:, :, 3] == 0, :3]) == 0, (name, i, "transparent RGB")
            assert tuple(frame["output_alpha_bbox_xyxy"]) == (int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1))
    print(f"PASS {name:13} {category:53} source={record['source_file']} v03={actual[:12]}")

assert [x["source_frame"] for x in candidate_entries["hit"]["frames"]] == [1, 2, 3, 4, 5]
assert [x["source_frame"] for x in candidate_entries["block"]["frames"]] == [2, 3, 4]
assert candidate_entries["death"]["frames"][-1]["scaled_size"][1] < candidate_entries["death"]["frames"][0]["scaled_size"][1]
assert candidate_entries["hit"]["frames"][3]["scaled_size"][1] < candidate_entries["hit"]["frames"][0]["scaled_size"][1]
assert candidate_entries["dodge"]["frames"][1]["scaled_size"][1] < candidate_entries["dodge"]["frames"][0]["scaled_size"][1]
print("PASS 17/17 live V03 bindings and hashes, 7 NEAREST, 10 staged R2 candidates, four source PNG hashes, geometry/alpha/baseline")
print("ACCEPTANCE: 7 clean live NEAREST source/runtime records accepted; 10 revised R2 states remain candidate-only pending direct art/grip/frame review")
