"""Verify exact accepted NPC sprite pixels in current real Godot consumer captures.

Capture first (non-headless):
    Godot --path . --script res://tools/art/capture_npc_live_consumers_v01.gd
Then from the inner Godot project:
    python tools/art/check_npc_live_renderer_v01.py

At Camera2D zoom=2, the (16,29) ground pivot places a 32px sprite at
screen x=288, y=122 on the 640x360 output. Check the displayed pixels,
not only the presence/hash of a screenshot file.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from PIL import Image

ART = Path(__file__).resolve().parents[2] / "assets/art/npc"
CAPTURE = ART / "review/live_consumer_v01"
SITES = (
    ("quest_hall_coordinator.png", "coordinator_anchor_v01.png"),
    ("blacksmith.png", "blacksmith_anchor_v01.png"),
    ("merchant.png", "merchant_anchor_v01.png"),
    ("region3_escort_at_authored_start.png", "escort_anchor_v01.png"),
    ("tower_escort_on_real_floor.png", "escort_anchor_v01.png"),
)
MAX_RGB_DIFFERENCE = 12
NEAR_OPAQUE = 250


def check() -> None:
    for scene_name, anchor_name in SITES:
        scene_file = CAPTURE / scene_name
        source_file = ART / anchor_name
        if not scene_file.is_file() or not source_file.is_file():
            raise AssertionError(f"Missing accepted sprite or renderer evidence: {scene_name}")
        with Image.open(scene_file) as stored, Image.open(source_file) as source:
            scene = stored.convert("RGBA")
            sprite = source.convert("RGBA")
        if scene.size != (640, 360) or sprite.size != (32, 32):
            raise AssertionError(f"Wrong renderer/source size: {scene_name} {scene.size} {sprite.size}")
        pixels = 0
        matched = 0
        for y in range(32):
            for x in range(32):
                rgb = sprite.getpixel((x, y))
                if rgb[3] < NEAR_OPAQUE:
                    continue
                pixels += 1
                native = scene.getpixel((288 + 2*x + 1, 122 + 2*y + 1))
                if max(abs(rgb[channel] - native[channel]) for channel in range(3)) <= MAX_RGB_DIFFERENCE:
                    matched += 1
        if pixels < 80 or matched != pixels:
            raise AssertionError(
                f"Accepted NPC not visibly aligned/rendered at authored consumer: "
                f"{scene_name}: {matched}/{pixels} near-opaque source pixels"
            )
        sha256 = hashlib.sha256(scene_file.read_bytes()).hexdigest()
        print(f"PASS {scene_name}: source pixels {matched}/{pixels}; 640x360; SHA-256 {sha256}")
    print("NPC REAL RENDERER PIXEL ACCEPTANCE: PASS 5/5")


if __name__ == "__main__":
    check()
