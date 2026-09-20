"""Verify six accepted NPC identity anchors without changing any source or derivative.

Run from the inner Godot project:
    python tools/art/audit_npc_static_anchors_v01.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
MANIFEST = PROJECT / "assets/art/npc/npc_identity_anchors_derivation_manifest.json"
SOURCE = "res://assets/art/generated_sources/imagegen/npc/npc_identity_anchors_source_v01.png"
SOURCE_SHA256 = "81f13fa706293b678f64d2f4bb163324b02c7b036eadf59dd3b80b6af551e23b"
ROLES = (
    ("coordinator", "tower_quest_coordinator"),
    ("merchant", "merchant"),
    ("blacksmith", "blacksmith_upgrader"),
    ("lore_elder", "story_lore"),
    ("variable_quest", "variable_quest"),
    ("escort", "temporary_escort"),
)


def path_from_res(value: str) -> Path:
    if not value.startswith("res://"):
        raise AssertionError(f"Not a project resource: {value}")
    result = PROJECT / value.removeprefix("res://")
    if not result.is_file():
        raise AssertionError(f"Missing file: {result}")
    return result


def digest(file: Path) -> str:
    return hashlib.sha256(file.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def derived_pixels(source: Image.Image, crop: tuple[int, ...]) -> Image.Image:
    frame = source.crop(crop).resize((32, 32), Image.Resampling.NEAREST)
    bbox = frame.getchannel("A").getbbox()
    require(bbox is not None, "Source cell is empty")
    cx = (bbox[0] + bbox[2] - 1) / 2
    bottom = bbox[3] - 1
    result = Image.new("RGBA", (32, 32))
    result.alpha_composite(frame, (round(16 - cx), round(30 - bottom)))
    pixels = result.load()
    for y in range(32):
        for x in range(32):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return result


def audit() -> None:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    require(data["source"]["path"] == SOURCE, "Source path changed")
    source_path = path_from_res(SOURCE)
    require(digest(source_path) == SOURCE_SHA256 == data["source"]["sha256"], "Source SHA-256 mismatch")
    source = Image.open(source_path)
    require(source.mode == "RGBA" and source.size == (1536, 1024), "Wrong source mode/size")
    outputs = data["outputs"]
    require(len(outputs) == len(ROLES), "Six identity records required")
    for index, (role, profile_name) in enumerate(ROLES):
        record = outputs[index]
        require(record["role"] == role, f"Wrong source cell order: {role}")
        col, row = index % 3, index // 3
        crop = (col * 512, row * 512, (col + 1) * 512, (row + 1) * 512)
        require(tuple(record["crop_rect_px"]) == crop, f"Crop changed: {role}")
        expected = derived_pixels(source, crop)
        review = path_from_res(record["review_source"])
        production = path_from_res(record["production_path"])
        require(digest(review) == digest(production) == record["output_sha256"] == record["review_sha256"] == record["production_sha256"], f"PNG bytes/hash mismatch: {role}")
        for name, file in (("review", review), ("production", production)):
            with Image.open(file) as image:
                require(image.mode == "RGBA" and image.size == (32, 32), f"Frame mode/size: {role}/{name}")
                require(image.tobytes() == expected.tobytes(), f"Source derivation differs: {role}/{name}")
                require(list(image.getchannel("A").getbbox()) == record["alpha_bbox_xyxy"], f"Alpha extent differs: {role}/{name}")
        require(record["ground_anchor"] == [16, 29], f"Ground anchor changed: {role}")
        profile_path = PROJECT / f"src/world/npc/presentation/profiles/{profile_name}.tres"
        profile = profile_path.read_text(encoding="utf-8")
        require(record["production_path"] in profile, f"Inspector profile not bound to production texture: {role}")
        require("frame_size = Vector2i(32, 32)" in profile and "ground_anchor = Vector2(16, 29)" in profile and "mirror_left = true" in profile, f"Profile canvas/mirroring changed: {role}")
        print(f"PASS {role}: cell {crop}; SHA-256 {digest(production)}; profile {profile_name}")
    # Verify the historical Godot renderer evidence is still the exact recorded capture.
    render_data = outputs[0]["renderer_evidence"]
    render_path = path_from_res(render_data["path"])
    require(digest(render_path) == render_data["sha256"], "Recorded renderer evidence hash mismatch")
    with Image.open(render_path) as render:
        require(list(render.size) == render_data["dimensions"], "Recorded renderer dimensions changed")
    print(f"PASS recorded renderer evidence: {render_data['path']} {render_data['dimensions']}")
    print("NPC STATIC ANCHORS AUDIT: PASS 6/6; motion and live placement are separate acceptance gates")


if __name__ == "__main__":
    audit()
